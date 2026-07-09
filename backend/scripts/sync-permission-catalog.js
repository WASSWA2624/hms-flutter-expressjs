/**
 * Sync canonical permission catalog and system roles for all tenants.
 *
 * Usage:
 *   node scripts/sync-permission-catalog.js
 */

const { prisma } = require('./seeders/seed-runtime');
const { ensureTenantAccessCatalog } = require('@lib/authorization/permission-catalog-sync');

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
    const result = await ensureTenantAccessCatalog(tenant.id);
    console.log(
      `Synced ${tenant.name || tenant.id}: ${result?.permissions ?? 0} permissions, ${result?.roles ?? 0} system roles`,
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
