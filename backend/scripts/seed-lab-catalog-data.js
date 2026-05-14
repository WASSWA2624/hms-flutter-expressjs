/**
 * Targeted lab catalog seed orchestration.
 *
 * Usage:
 *   node scripts/seed-lab-catalog-data.js
 */

const {
  createSeedContext,
  DEFAULT_RANDOM_SEED,
  prisma,
} = require('./seeders/seed-runtime');
const env = require('@config/env');
const { seedOrgPack } = require('./seeders/seed-org-pack');
const {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
  seedLabCatalogForTenant,
  seedLabCatalogPack,
} = require('./seeders/seed-lab-catalog-pack');

const resolveNumericEnv = (value, fallback) => {
  const parsed = Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const seedLabCatalogData = async ({
  randomSeed = DEFAULT_RANDOM_SEED,
} = {}) => {
  if (env.NODE_ENV === 'production') {
    console.warn('Skipping lab catalog seed: NODE_ENV=production');
    return { skipped: true, reason: 'production_environment' };
  }

  const ctx = createSeedContext({
    randomSeed,
    recordCount: 0,
  });

  console.log(`Seeding lab catalog with random seed ${ctx.randomSeed}...`);

  const orgPack = await seedOrgPack(ctx);
  const labCatalogPack = await seedLabCatalogPack(ctx, orgPack);
  const seededTenantIds = new Set(
    Object.values(orgPack.tenants || {})
      .map((tenant) => String(tenant?.id || '').trim())
      .filter(Boolean)
  );

  const additionalTenants = await prisma.tenant.findMany({
    where: {
      deleted_at: null,
      ...(seededTenantIds.size > 0 ? { id: { notIn: Array.from(seededTenantIds) } } : {}),
    },
    orderBy: { name: 'asc' },
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  });

  for (const tenant of additionalTenants) {
    const tenantResult = await seedLabCatalogForTenant(ctx, {
      seedKey: `tenant:${tenant.id}`,
      tenantId: tenant.id,
      tenantCode: tenant.human_friendly_id || tenant.id,
      scenarioKey: 'EXISTING',
    });
    labCatalogPack.summary.tenants += 1;
    Object.entries(tenantResult.tests).forEach(([testKey, record]) => {
      labCatalogPack.tests[`tenant:${tenant.id}:${testKey}`] = record;
    });
    Object.entries(tenantResult.panels).forEach(([panelKey, record]) => {
      labCatalogPack.panels[`tenant:${tenant.id}:${panelKey}`] = record;
    });
  }

  console.log('Lab catalog seeded successfully.');

  return {
    skipped: false,
    summary: {
      ...labCatalogPack.summary,
      tests_per_tenant: LAB_TEST_CATALOG.length,
      panels_per_tenant: LAB_PANEL_CATALOG.length,
      additional_tenants_seeded: additionalTenants.length,
    },
  };
};

const main = async () => {
  try {
    await seedLabCatalogData({
      randomSeed: resolveNumericEnv(env.SEED_RANDOM_SEED, DEFAULT_RANDOM_SEED),
    });
  } catch (error) {
    console.error('Failed to seed lab catalog:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  seedLabCatalogData,
};
