/**
 * Compatibility wrapper for demo tenant and account setup.
 *
 * Usage:
 *   node scripts/setup-default-accounts.js
 */

const {
  createSeedContext,
  DEFAULT_RANDOM_SEED,
  DEFAULT_SEED_PASSWORD,
  prisma,
} = require('./seeders/seed-runtime');
const { seedOrgPack } = require('./seeders/seed-org-pack');
const { seedAccessPack } = require('./seeders/seed-access-pack');

const setupDefaultAccounts = async ({ randomSeed = DEFAULT_RANDOM_SEED } = {}) => {
  const ctx = createSeedContext({ randomSeed, recordCount: 0 });
  const orgPack = await seedOrgPack(ctx);
  const accessPack = await seedAccessPack(ctx, orgPack);

  return {
    tenants: Object.keys(orgPack.tenants),
    users: Object.keys(accessPack.users),
    defaultPassword: DEFAULT_SEED_PASSWORD,
  };
};

const main = async () => {
  try {
    const result = await setupDefaultAccounts();
    console.log(`Seeded ${result.tenants.length} tenant(s) and ${result.users.length} user account(s).`);
    console.log(`Default password: ${result.defaultPassword}`);
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
