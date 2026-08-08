/**
 * Reseed platform-scoped default roles + permissions and consolidate duplicates.
 *
 * Usage:
 *   node scripts/reseed-platform-access-catalog.js
 */

const { prisma } = require('./seeders/seed-runtime');
const {
  ensurePlatformAccessCatalog,
  consolidateTenantCatalogDuplicates,
  clearAccessCatalogCache,
} = require('@lib/authorization/permission-catalog-sync');

const main = async () => {
  clearAccessCatalogCache();
  console.log('Seeding platform access catalog...');
  const seeded = await ensurePlatformAccessCatalog({ force: true });
  console.log(
    `Platform catalog ready: ${seeded.permissions} permissions, ${seeded.roles} roles`
  );

  console.log('Consolidating tenant-local catalog duplicates...');
  const consolidated = await consolidateTenantCatalogDuplicates();
  console.log(JSON.stringify(consolidated, null, 2));
  console.log('Done.');
};

main()
  .catch((error) => {
    console.error('Platform access catalog reseed failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
