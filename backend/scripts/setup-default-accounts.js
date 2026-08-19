/**
 * Tenant + default account setup.
 *
 * Runs in every environment, production included: the curated accounts in
 * seed-catalog.js are the standard login set for the platform, not demo-only
 * fixtures. Only the randomised demo *data* seeders stay gated by demo-safety.
 *
 * Set SEED_DEFAULT_PASSWORD to override the committed shared password.
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

const setupDefaultAccounts = async ({ randomSeed = DEFAULT_RANDOM_SEED } = {}) => {
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
    console.log(`Setting up default accounts (NODE_ENV=${process.env.NODE_ENV || 'development'})...`);
    const result = await setupDefaultAccounts();

    console.log(`Seeded ${result.tenants.length} tenant(s) and ${result.users.length} user account(s).`);
    console.log('The shared default password is intentionally not printed by this script.');
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
