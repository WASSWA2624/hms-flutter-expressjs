/**
 * Compatibility wrapper for demo tenant and account setup.
 *
 * Usage:
 *   node scripts/setup-default-accounts.js
 */

const {
  createSeedContext,
  DEFAULT_RANDOM_SEED,
  prisma,
} = require('./seeders/seed-runtime');
const { seedOrgPack } = require('./seeders/seed-org-pack');
const { seedAccessPack } = require('./seeders/seed-access-pack');
const { assertDemoTaskAllowed } = require('./demo-safety');

const setupDefaultAccounts = async ({ randomSeed = DEFAULT_RANDOM_SEED } = {}) => {
  const safety = assertDemoTaskAllowed('default demo account setup');
  if (!safety.allowed) {
    console.warn('Skipping default account setup: NODE_ENV=production');
    return { skipped: true, reason: safety.reason };
  }

  const ctx = createSeedContext({ randomSeed, recordCount: 0 });
  const orgPack = await seedOrgPack(ctx);
  const accessPack = await seedAccessPack(ctx, orgPack);

  return {
    skipped: false,
    tenants: Object.keys(orgPack.tenants),
    users: Object.keys(accessPack.users),
  };
};

const main = async () => {
  try {
    const result = await setupDefaultAccounts();
    if (result.skipped) return;

    console.log(`Seeded ${result.tenants.length} tenant(s) and ${result.users.length} user account(s).`);
    console.log('Default demo password is intentionally not printed by this script.');
  } catch (error) {
    console.error('Failed to set up default accounts:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  setupDefaultAccounts,
};
