/**
 * Sync canonical permission catalog and system roles from config into tenant DB rows.
 *
 * Hot paths (reference-data / workspace) use a short in-memory TTL cache and only
 * create missing rows — they do not rewrite metadata on every request.
 *
 * @module lib/authorization/permission-catalog-sync
 */

const crypto = require('crypto');
const prisma = require('@prisma/client');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');
const {
  getPermissionMetadata,
  getRoleMetadata,
} = require('@config/permission-catalog-metadata');

const CANONICAL_PERMISSION_KEYS = Object.freeze(
  Array.from(new Set(Object.values(PERMISSIONS))).sort()
);

const SYSTEM_ROLE_CODES = Object.freeze(Object.keys(ROLE_PERMISSIONS).sort());

const CATALOG_TTL_MS = Number(process.env.ACCESS_CATALOG_CACHE_TTL_MS || 5 * 60 * 1000);

/** @type {Map<string, { at: number, records: Object[] }>} */
const permissionCatalogCache = new Map();

/** @type {Map<string, { at: number, permissions: number, roles: number }>} */
const accessCatalogCache = new Map();

const friendlyId = (prefix, key) =>
  `${prefix}-${crypto.createHash('sha256').update(String(key || '')).digest('hex').slice(0, 10).toUpperCase()}`;

const findPermissionByName = async (tenantId, name) =>
  prisma.permission.findFirst({
    where: {
      tenant_id: tenantId,
      name,
      deleted_at: null,
    },
  });

const upsertPermission = async (tenantId, name) => {
  const { displayName, description } = getPermissionMetadata(name);
  const existing = await findPermissionByName(tenantId, name);

  if (existing) {
    return prisma.permission.update({
      where: { id: existing.id },
      data: {
        display_name: displayName,
        description,
      },
    });
  }

  return prisma.permission.create({
    data: {
      tenant_id: tenantId,
      name,
      display_name: displayName,
      description,
      human_friendly_id: friendlyId('PERM', `${tenantId}:${name}`),
    },
  });
};

const loadPermissionMap = async (tenantId) => {
  const records = await prisma.permission.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      name: { in: [...CANONICAL_PERMISSION_KEYS] },
    },
  });

  return new Map(records.map((entry) => [entry.name, entry]));
};

const syncPermissionsForTenant = async (tenantId, names = CANONICAL_PERMISSION_KEYS) => {
  const permissionMap = new Map();

  for (const name of names) {
    const permission = await upsertPermission(tenantId, name);
    permissionMap.set(name, permission);
  }

  return permissionMap;
};

const findRoleByName = async (tenantId, roleName) =>
  prisma.role.findFirst({
    where: {
      tenant_id: tenantId,
      name: roleName,
      deleted_at: null,
    },
  });

const upsertRolePermissionLink = async (roleId, permissionId) => {
  const existing = await prisma.role_permission.findFirst({
    where: {
      role_id: roleId,
      permission_id: permissionId,
      deleted_at: null,
    },
  });

  if (existing) {
    return existing;
  }

  return prisma.role_permission.create({
    data: {
      role_id: roleId,
      permission_id: permissionId,
      human_friendly_id: friendlyId('RPERM', `${roleId}:${permissionId}`),
    },
  });
};

const syncSystemRole = async (tenantId, roleName, permissionMap, { refreshMetadata = true } = {}) => {
  const { displayName, description } = getRoleMetadata(roleName);
  let role = await findRoleByName(tenantId, roleName);

  if (!role) {
    role = await prisma.role.create({
      data: {
        tenant_id: tenantId,
        name: roleName,
        display_name: displayName,
        description,
        human_friendly_id: friendlyId('ROLE', `${tenantId}:${roleName}`),
      },
    });
  } else if (refreshMetadata) {
    role = await prisma.role.update({
      where: { id: role.id },
      data: {
        display_name: displayName,
        description,
      },
    });
  }

  const permissionKeys = ROLE_PERMISSIONS[roleName] || [];
  for (const permissionName of permissionKeys) {
    const permission =
      permissionMap.get(permissionName) ||
      (await upsertPermission(tenantId, permissionName));
    permissionMap.set(permissionName, permission);
    await upsertRolePermissionLink(role.id, permission.id);
  }

  return role;
};

const syncSystemRolesForTenant = async (
  tenantId,
  permissionMap,
  roleNames = SYSTEM_ROLE_CODES,
  options = {}
) => {
  for (const roleName of roleNames) {
    await syncSystemRole(tenantId, roleName, permissionMap, options);
  }
};

const countSystemRoles = async (tenantId) =>
  prisma.role.count({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      name: { in: [...SYSTEM_ROLE_CODES] },
    },
  });

const readCachedPermissionCatalog = (tenantId) => {
  const cached = permissionCatalogCache.get(tenantId);
  if (!cached) {
    return null;
  }
  if (Date.now() - cached.at > CATALOG_TTL_MS) {
    permissionCatalogCache.delete(tenantId);
    return null;
  }
  return cached.records;
};

const writeCachedPermissionCatalog = (tenantId, records) => {
  permissionCatalogCache.set(tenantId, { at: Date.now(), records });
};

const ensureTenantPermissionCatalog = async (tenantId, { force = false } = {}) => {
  if (!tenantId) {
    return [];
  }

  if (!force) {
    const cached = readCachedPermissionCatalog(tenantId);
    if (cached) {
      return cached;
    }
  }

  const existing = await prisma.permission.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      name: { in: [...CANONICAL_PERMISSION_KEYS] },
    },
    orderBy: { name: 'asc' },
  });

  const existingNames = new Set(existing.map((entry) => entry.name));
  const missing = CANONICAL_PERMISSION_KEYS.filter((name) => !existingNames.has(name));

  let records = existing;
  if (missing.length > 0) {
    await prisma.permission.createMany({
      data: missing.map((name) => {
        const { displayName, description } = getPermissionMetadata(name);
        return {
          tenant_id: tenantId,
          name,
          display_name: displayName,
          description,
          human_friendly_id: friendlyId('PERM', `${tenantId}:${name}`),
        };
      }),
    });

    records = await prisma.permission.findMany({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
      },
      orderBy: { name: 'asc' },
    });
  }

  writeCachedPermissionCatalog(tenantId, records);
  return records;
};

/**
 * Fast path for workspace/reference-data: ensure missing catalog rows exist.
 * Skips per-row metadata rewrites once the catalog is complete.
 */
const ensureTenantAccessCatalog = async (tenantId, { force = false } = {}) => {
  if (!tenantId) {
    return null;
  }

  if (!force) {
    const cached = accessCatalogCache.get(tenantId);
    if (cached && Date.now() - cached.at <= CATALOG_TTL_MS) {
      return { permissions: cached.permissions, roles: cached.roles };
    }
  }

  const permissionRecords = await ensureTenantPermissionCatalog(tenantId, { force });
  const permissionMap = new Map(permissionRecords.map((entry) => [entry.name, entry]));

  const existingRoles = await prisma.role.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      name: { in: [...SYSTEM_ROLE_CODES] },
    },
    select: { id: true, name: true },
  });
  const existingRoleNames = new Set(existingRoles.map((entry) => entry.name));
  const missingRoleNames = SYSTEM_ROLE_CODES.filter((name) => !existingRoleNames.has(name));

  if (missingRoleNames.length > 0) {
    await syncSystemRolesForTenant(tenantId, permissionMap, missingRoleNames, {
      refreshMetadata: false,
    });
  }

  const roles = existingRoles.length + missingRoleNames.length;
  const result = {
    permissions: permissionRecords.length,
    roles,
  };
  accessCatalogCache.set(tenantId, { at: Date.now(), ...result });
  return result;
};

/**
 * Full metadata refresh (slower). Prefer ensureTenantAccessCatalog for request paths.
 */
const refreshTenantAccessCatalog = async (tenantId) => {
  if (!tenantId) {
    return null;
  }
  permissionCatalogCache.delete(tenantId);
  accessCatalogCache.delete(tenantId);

  const permissionMap = await syncPermissionsForTenant(tenantId);
  await syncSystemRolesForTenant(tenantId, permissionMap, SYSTEM_ROLE_CODES, {
    refreshMetadata: true,
  });

  const [permissions, roles] = await Promise.all([
    prisma.permission.count({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
      },
    }),
    countSystemRoles(tenantId),
  ]);

  const permissionRecords = await ensureTenantPermissionCatalog(tenantId, { force: true });
  accessCatalogCache.set(tenantId, { at: Date.now(), permissions, roles });
  writeCachedPermissionCatalog(tenantId, permissionRecords);

  return { permissions, roles };
};

const clearAccessCatalogCache = (tenantId = null) => {
  if (tenantId) {
    permissionCatalogCache.delete(tenantId);
    accessCatalogCache.delete(tenantId);
    return;
  }
  permissionCatalogCache.clear();
  accessCatalogCache.clear();
};

module.exports = {
  CANONICAL_PERMISSION_KEYS,
  SYSTEM_ROLE_CODES,
  clearAccessCatalogCache,
  ensureTenantAccessCatalog,
  ensureTenantPermissionCatalog,
  refreshTenantAccessCatalog,
  syncPermissionsForTenant,
  syncSystemRolesForTenant,
};
