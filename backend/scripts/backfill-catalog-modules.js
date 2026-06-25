#!/usr/bin/env node
/**
 * Upsert catalog modules and module subscriptions for existing tenants.
 *
 * Use after adding new modules to seed-catalog.js without re-running the full demo seed.
 *
 * Usage:
 *   node scripts/backfill-catalog-modules.js
 */

const { createSeedContext, prisma } = require('./seeders/seed-runtime');
const { seedOrgPack } = require('./seeders/seed-org-pack');
const { seedSubscriptionsPack } = require('./seeders/seed-subscriptions-pack');
const { assertDemoTaskAllowed } = require('./demo-safety');

const main = async () => {
  const safety = assertDemoTaskAllowed('catalog module backfill');
  if (!safety.allowed) {
    console.warn('Skipping backfill: NODE_ENV=production');
    return;
  }

  const ctx = createSeedContext();
  console.log('Backfilling catalog modules and subscriptions...');

  const orgPack = await seedOrgPack(ctx);
  const subscriptionsPack = await seedSubscriptionsPack(ctx, orgPack);

  const moduleCount = Object.keys(subscriptionsPack.modules || {}).length;
  console.log(`Catalog modules upserted: ${moduleCount}`);
  console.log('Module subscriptions synchronized for demo tenant subscriptions.');
};

main()
  .catch((error) => {
    console.error(`Catalog module backfill failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
