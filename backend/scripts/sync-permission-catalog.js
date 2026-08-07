/**
 * Sync canonical permission catalog and restore system role packs for all tenants.
 *
 * Usage:
 *   node scripts/sync-permission-catalog.js
 *
 * Uses restoreTenantRolePermissionDefaults so ROLE_PERMISSIONS pack changes
 * (additions and removals) are written to tenant role_permission rows.
 */

const { prisma } = require('./seeders/seed-runtime');
const {
  ensureTenantAccessCatalog,
  restoreTenantRolePermissionDefaults,
  clearAccessCatalogCache,
} = require('@lib/authorization/permission-catalog-sync');

const main = async () => {
  const tenants = await prisma.tenant.findMany({
    where: { deleted_at: null },
    select: { id: true, name: true },
    orderBy: { name: 'asc' },
  });

  if (tenants.length === 0) {
    console.log('No tenants found. Nothing to sync.');
    return;
  }

  for (const tenant of tenants) {
    clearAccessCatalogCache(tenant.id);
    await ensureTenantAccessCatalog(tenant.id, { force: true });
    const restored = await restoreTenantRolePermissionDefaults(tenant.id);
    console.log(
      `Synced ${tenant.name || tenant.id}: ${restored?.permissions ?? 0} permissions, ` +
        `${Object.keys(restored?.after || {}).length} system roles ` +
        `(+${restored?.role_permissions_added ?? 0}/-${restored?.role_permissions_removed ?? 0} role links)`,
    );
  }
};

main()
  .catch((error) => {
    console.error('Permission catalog sync failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
