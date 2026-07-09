/**
 * Sync canonical permission catalog and system roles from config into tenant DB rows.
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

const syncSystemRole = async (tenantId, roleName, permissionMap) => {
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
  } else {
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

const syncSystemRolesForTenant = async (tenantId, permissionMap, roleNames = SYSTEM_ROLE_CODES) => {
  for (const roleName of roleNames) {
    await syncSystemRole(tenantId, roleName, permissionMap);
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

const ensureTenantPermissionCatalog = async (tenantId) => {
  if (!tenantId) {
    return [];
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

    return prisma.permission.findMany({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
      },
      orderBy: { name: 'asc' },
    });
  }

  return existing;
};

/**
 * Idempotently ensures tenant permission catalog and system roles exist with metadata.
 *
 * @param {string} tenantId
 * @returns {Promise<{ permissions: number, roles: number }|null>}
 */
const ensureTenantAccessCatalog = async (tenantId) => {
  if (!tenantId) {
    return null;
  }

  const permissionMap = await syncPermissionsForTenant(tenantId);
  await syncSystemRolesForTenant(tenantId, permissionMap);

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

  return { permissions, roles };
};

module.exports = {
  CANONICAL_PERMISSION_KEYS,
  SYSTEM_ROLE_CODES,
  ensureTenantAccessCatalog,
  ensureTenantPermissionCatalog,
  syncPermissionsForTenant,
  syncSystemRolesForTenant,
};
