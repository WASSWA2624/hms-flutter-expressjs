/**
 * Platform-scoped access catalog (roles + permissions with tenant_id null).
 *
 * Default/system roles and permissions live once at platform scope. Tenant actors
 * can read them; only platform admins may mutate them. Tenant-local clones of the
 * catalog are consolidated away to prevent duplicates.
 *
 * @module lib/authorization/platform-access-catalog
 */

const crypto = require('crypto');
const prisma = require('@prisma/client');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');
const {
  getPermissionMetadata,
  getRoleMetadata,
} = require('@config/permission-catalog-metadata');
const { runWithoutTenantGuard } = require('../../prisma/tenant-guard');

const CANONICAL_PERMISSION_KEYS = Object.freeze(
  Array.from(new Set(Object.values(PERMISSIONS))).sort()
);

const SYSTEM_ROLE_CODES = Object.freeze(Object.keys(ROLE_PERMISSIONS).sort());

const friendlyId = (prefix, key) =>
  `${prefix}-${crypto
    .createHash('sha256')
    .update(String(key || ''))
    .digest('hex')
    .slice(0, 10)
    .toUpperCase()}`;

const nowIso = () => new Date();

const findPlatformPermissionByName = async (name, client = prisma) =>
  client.permission.findFirst({
    where: {
      tenant_id: null,
      name,
      deleted_at: null,
    },
    orderBy: [{ created_at: 'asc' }],
  });

const findPlatformRoleByName = async (name, client = prisma) =>
  client.role.findFirst({
    where: {
      tenant_id: null,
      facility_id: null,
      name,
      deleted_at: null,
    },
    orderBy: [{ created_at: 'asc' }],
  });

const upsertPlatformPermission = async (name, client = prisma) => {
  const { displayName, description } = getPermissionMetadata(name);
  const existing = await findPlatformPermissionByName(name, client);
  if (existing) {
    return client.permission.update({
      where: { id: existing.id },
      data: {
        display_name: displayName,
        description,
        tenant_id: null,
      },
    });
  }

  return client.permission.create({
    data: {
      tenant_id: null,
      name,
      display_name: displayName,
      description,
      human_friendly_id: friendlyId('PERM', `platform:${name}`),
    },
  });
};

const upsertRolePermissionLink = async (roleId, permissionId, client = prisma) => {
  const existing = await client.role_permission.findFirst({
    where: {
      role_id: roleId,
      permission_id: permissionId,
    },
  });

  if (existing) {
    if (existing.deleted_at) {
      return client.role_permission.update({
        where: { id: existing.id },
        data: { deleted_at: null },
      });
    }
    return existing;
  }

  return client.role_permission.create({
    data: {
      role_id: roleId,
      permission_id: permissionId,
      human_friendly_id: friendlyId('RPERM', `${roleId}:${permissionId}`),
    },
  });
};

const upsertPlatformRole = async (roleName, permissionMap, client = prisma) => {
  const { displayName, description } = getRoleMetadata(roleName);
  let role = await findPlatformRoleByName(roleName, client);

  if (!role) {
    role = await client.role.create({
      data: {
        tenant_id: null,
        facility_id: null,
        name: roleName,
        display_name: displayName,
        description,
        human_friendly_id: friendlyId('ROLE', `platform:${roleName}`),
      },
    });
  } else {
    role = await client.role.update({
      where: { id: role.id },
      data: {
        display_name: displayName,
        description,
        tenant_id: null,
        facility_id: null,
      },
    });
  }

  const desiredNames = new Set(ROLE_PERMISSIONS[roleName] || []);
  const existingLinks = await client.role_permission.findMany({
    where: { role_id: role.id, deleted_at: null },
    include: { permission: true },
  });

  for (const link of existingLinks) {
    const permissionName = link.permission?.name;
    if (!desiredNames.has(permissionName)) {
      await client.role_permission.update({
        where: { id: link.id },
        data: { deleted_at: nowIso() },
      });
    }
  }

  for (const permissionName of desiredNames) {
    let permission = permissionMap.get(permissionName);
    if (!permission) {
      permission = await upsertPlatformPermission(permissionName, client);
      permissionMap.set(permissionName, permission);
    }
    await upsertRolePermissionLink(role.id, permission.id, client);
  }

  return role;
};

/**
 * Seed / refresh the single platform catalog (no tenant copies).
 */
const ensurePlatformAccessCatalog = async ({ force = false } = {}) =>
  runWithoutTenantGuard(async () => {
    const permissionMap = new Map();
    for (const name of CANONICAL_PERMISSION_KEYS) {
      const permission = await upsertPlatformPermission(name);
      permissionMap.set(name, permission);
    }

    for (const roleName of SYSTEM_ROLE_CODES) {
      await upsertPlatformRole(roleName, permissionMap);
    }

    // Soft-delete duplicate platform rows (keep oldest active).
    for (const name of CANONICAL_PERMISSION_KEYS) {
      const rows = await prisma.permission.findMany({
        where: { tenant_id: null, name, deleted_at: null },
        orderBy: [{ created_at: 'asc' }],
      });
      for (const duplicate of rows.slice(1)) {
        await prisma.permission.update({
          where: { id: duplicate.id },
          data: { deleted_at: nowIso() },
        });
      }
    }

    for (const roleName of SYSTEM_ROLE_CODES) {
      const rows = await prisma.role.findMany({
        where: {
          tenant_id: null,
          facility_id: null,
          name: roleName,
          deleted_at: null,
        },
        orderBy: [{ created_at: 'asc' }],
      });
      for (const duplicate of rows.slice(1)) {
        await prisma.role.update({
          where: { id: duplicate.id },
          data: { deleted_at: nowIso() },
        });
      }
    }

    const [permissions, roles] = await Promise.all([
      prisma.permission.count({
        where: {
          tenant_id: null,
          deleted_at: null,
          name: { in: [...CANONICAL_PERMISSION_KEYS] },
        },
      }),
      prisma.role.count({
        where: {
          tenant_id: null,
          facility_id: null,
          deleted_at: null,
          name: { in: [...SYSTEM_ROLE_CODES] },
        },
      }),
    ]);

    return {
      permissions,
      roles,
      force: Boolean(force),
    };
  });

const loadPlatformPermissionMap = async () =>
  runWithoutTenantGuard(async () => {
    const records = await prisma.permission.findMany({
      where: {
        tenant_id: null,
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
      },
    });
    return new Map(records.map((entry) => [entry.name, entry]));
  });

const loadPlatformRoleMap = async () =>
  runWithoutTenantGuard(async () => {
    const records = await prisma.role.findMany({
      where: {
        tenant_id: null,
        facility_id: null,
        deleted_at: null,
        name: { in: [...SYSTEM_ROLE_CODES] },
      },
    });
    return new Map(records.map((entry) => [entry.name, entry]));
  });

/**
 * Remap tenant-local catalog clones onto the platform catalog and soft-delete
 * the clones so the catalog is not duplicated per tenant.
 */
const consolidateTenantCatalogDuplicates = async () =>
  runWithoutTenantGuard(async () => {
    await ensurePlatformAccessCatalog({ force: true });
    const platformPermissions = await loadPlatformPermissionMap();
    const platformRoles = await loadPlatformRoleMap();

    let remappedUserRoles = 0;
    let remappedRolePermissions = 0;
    let remappedUserPermissions = 0;
    let softDeletedRoles = 0;
    let softDeletedPermissions = 0;

    const tenantSystemRoles = await prisma.role.findMany({
      where: {
        deleted_at: null,
        name: { in: [...SYSTEM_ROLE_CODES] },
        NOT: { tenant_id: null },
      },
      select: { id: true, name: true, tenant_id: true },
    });

    for (const tenantRole of tenantSystemRoles) {
      const platformRole = platformRoles.get(tenantRole.name);
      if (!platformRole) {
        continue;
      }

      const updated = await prisma.user_role.updateMany({
        where: { role_id: tenantRole.id, deleted_at: null },
        data: { role_id: platformRole.id },
      });
      remappedUserRoles += updated.count;

      await prisma.role_permission.updateMany({
        where: { role_id: tenantRole.id, deleted_at: null },
        data: { deleted_at: nowIso() },
      });

      await prisma.role.update({
        where: { id: tenantRole.id },
        data: { deleted_at: nowIso() },
      });
      softDeletedRoles += 1;
    }

    const tenantCatalogPermissions = await prisma.permission.findMany({
      where: {
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
        NOT: { tenant_id: null },
      },
      select: { id: true, name: true, tenant_id: true },
    });

    for (const tenantPermission of tenantCatalogPermissions) {
      const platformPermission = platformPermissions.get(tenantPermission.name);
      if (!platformPermission) {
        continue;
      }

      const roleLinks = await prisma.role_permission.findMany({
        where: { permission_id: tenantPermission.id, deleted_at: null },
      });

      for (const link of roleLinks) {
        const existing = await prisma.role_permission.findFirst({
          where: {
            role_id: link.role_id,
            permission_id: platformPermission.id,
          },
        });
        if (existing) {
          if (existing.deleted_at) {
            await prisma.role_permission.update({
              where: { id: existing.id },
              data: { deleted_at: null },
            });
          }
          await prisma.role_permission.update({
            where: { id: link.id },
            data: { deleted_at: nowIso() },
          });
        } else {
          await prisma.role_permission.update({
            where: { id: link.id },
            data: { permission_id: platformPermission.id },
          });
        }
        remappedRolePermissions += 1;
      }

      const userLinks = await prisma.user_permission.findMany({
        where: { permission_id: tenantPermission.id, deleted_at: null },
      });

      for (const link of userLinks) {
        const existing = await prisma.user_permission.findFirst({
          where: {
            user_id: link.user_id,
            permission_id: platformPermission.id,
          },
        });
        if (existing) {
          if (existing.deleted_at) {
            await prisma.user_permission.update({
              where: { id: existing.id },
              data: { deleted_at: null },
            });
          }
          await prisma.user_permission.update({
            where: { id: link.id },
            data: { deleted_at: nowIso() },
          });
        } else {
          await prisma.user_permission.update({
            where: { id: link.id },
            data: { permission_id: platformPermission.id },
          });
        }
        remappedUserPermissions += 1;
      }

      await prisma.permission.update({
        where: { id: tenantPermission.id },
        data: { deleted_at: nowIso() },
      });
      softDeletedPermissions += 1;
    }

    return {
      remapped_user_roles: remappedUserRoles,
      remapped_role_permissions: remappedRolePermissions,
      remapped_user_permissions: remappedUserPermissions,
      soft_deleted_roles: softDeletedRoles,
      soft_deleted_permissions: softDeletedPermissions,
      platform_permissions: platformPermissions.size,
      platform_roles: platformRoles.size,
    };
  });

const listPlatformPermissions = async () =>
  runWithoutTenantGuard(() =>
    prisma.permission.findMany({
      where: {
        tenant_id: null,
        deleted_at: null,
        name: { in: [...CANONICAL_PERMISSION_KEYS] },
      },
      orderBy: { name: 'asc' },
    })
  );

module.exports = {
  CANONICAL_PERMISSION_KEYS,
  SYSTEM_ROLE_CODES,
  consolidateTenantCatalogDuplicates,
  ensurePlatformAccessCatalog,
  listPlatformPermissions,
  loadPlatformPermissionMap,
  loadPlatformRoleMap,
};
