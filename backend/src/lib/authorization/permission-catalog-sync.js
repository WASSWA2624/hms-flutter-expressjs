/**
 * Sync canonical permission catalog and system roles from config into tenant DB rows.
 *
 * @module lib/authorization/permission-catalog-sync
 */

const crypto = require('crypto');
const prisma = require('@prisma/client');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');

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
  const existing = await findPermissionByName(tenantId, name);
  if (existing) {
    return existing;
  }

  return prisma.permission.create({
    data: {
      tenant_id: tenantId,
      name,
      description: `${name} permission`,
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
  const permissionMap = await loadPermissionMap(tenantId);
  const missing = names.filter((name) => !permissionMap.has(name));

  for (const name of missing) {
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
  let role = await findRoleByName(tenantId, roleName);
  if (!role) {
    role = await prisma.role.create({
      data: {
        tenant_id: tenantId,
        name: roleName,
        description: `${roleName} system role`,
        human_friendly_id: friendlyId('ROLE', `${tenantId}:${roleName}`),
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

/**
 * Idempotently ensures tenant permission catalog and system roles exist.
 *
 * @param {string} tenantId
 * @returns {Promise<{ permissions: number, roles: number }|null>}
 */
const ensureTenantAccessCatalog = async (tenantId) => {
  if (!tenantId) {
    return null;
  }

  const [existingPermissions, existingSystemRoles] = await Promise.all([
    prisma.permission.count({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
      },
    }),
    countSystemRoles(tenantId),
  ]);

  const needsPermissionSync = existingPermissions < CANONICAL_PERMISSION_KEYS.length;
  const needsRoleSync = existingSystemRoles < SYSTEM_ROLE_CODES.length;

  if (!needsPermissionSync && !needsRoleSync) {
    return {
      permissions: existingPermissions,
      roles: existingSystemRoles,
    };
  }

  const permissionMap = needsPermissionSync
    ? await syncPermissionsForTenant(tenantId)
    : await loadPermissionMap(tenantId);

  if (needsRoleSync) {
    const missingRoles = [];
    for (const roleName of SYSTEM_ROLE_CODES) {
      const role = await findRoleByName(tenantId, roleName);
      if (!role) {
        missingRoles.push(roleName);
      }
    }
    if (missingRoles.length > 0) {
      await syncSystemRolesForTenant(tenantId, permissionMap, missingRoles);
    }
  }

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
  syncPermissionsForTenant,
  syncSystemRolesForTenant,
};
