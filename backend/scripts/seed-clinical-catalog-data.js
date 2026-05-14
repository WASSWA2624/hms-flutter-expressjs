/**
 * Targeted clinical catalog seed orchestration.
 *
 * Usage:
 *   node scripts/seed-clinical-catalog-data.js
 */

const {
  createSeedContext,
  DEFAULT_RANDOM_SEED,
  prisma,
} = require('./seeders/seed-runtime');
const env = require('@config/env');
const { seedOrgPack } = require('./seeders/seed-org-pack');
const {
  seedClinicalCatalogForTenant,
  seedClinicalCatalogPack,
} = require('./seeders/seed-clinical-catalog-pack');

const resolveNumericEnv = (value, fallback) => {
  const parsed = Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const mergeTenantCatalogRecords = (target, scopeKey, records = {}) => {
  Object.entries(records || {}).forEach(([recordKey, record]) => {
    target[`${scopeKey}:${recordKey}`] = record;
  });
};

const seedClinicalCatalogData = async ({
  randomSeed = DEFAULT_RANDOM_SEED,
} = {}) => {
  if (env.NODE_ENV === 'production') {
    console.warn('Skipping clinical catalog seed: NODE_ENV=production');
    return { skipped: true, reason: 'production_environment' };
  }

  const ctx = createSeedContext({
    randomSeed,
    recordCount: 0,
  });

  console.log(`Seeding clinical catalog with random seed ${ctx.randomSeed}...`);

  const orgPack = await seedOrgPack(ctx);
  const clinicalCatalogPack = await seedClinicalCatalogPack(ctx, orgPack);
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
      facilities: {
        where: { deleted_at: null },
        select: { id: true },
      },
    },
  });

  for (const tenant of additionalTenants) {
    const facilityIds = (tenant.facilities || []).map((facility) => facility.id).filter(Boolean);
    const tenantResult = await seedClinicalCatalogForTenant(ctx, {
      seedKey: `tenant:${tenant.id}`,
      tenantId: tenant.id,
      tenantCode: tenant.human_friendly_id || tenant.id,
      scenarioKey: 'EXISTING',
      facilityIds,
    });

    clinicalCatalogPack.summary.tenants += 1;
    clinicalCatalogPack.summary.facilities_seeded += facilityIds.length;
    clinicalCatalogPack.summary.stock_records_seeded += Object.keys(
      tenantResult.pharmacy.inventoryStocks || {}
    ).length;
    clinicalCatalogPack.summary.stock_movements_seeded += Object.keys(
      tenantResult.pharmacy.stockMovements || {}
    ).length;

    mergeTenantCatalogRecords(clinicalCatalogPack.lab.tests, `tenant:${tenant.id}`, tenantResult.lab.tests);
    mergeTenantCatalogRecords(clinicalCatalogPack.lab.panels, `tenant:${tenant.id}`, tenantResult.lab.panels);
    mergeTenantCatalogRecords(
      clinicalCatalogPack.radiology.tests,
      `tenant:${tenant.id}`,
      tenantResult.radiology.tests
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.drugs,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.drugs
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.formularyItems,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.formularyItems
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.inventoryItems,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.inventoryItems
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.inventoryMaps,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.inventoryMaps
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.drugBatches,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.drugBatches
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.inventoryStocks,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.inventoryStocks
    );
    mergeTenantCatalogRecords(
      clinicalCatalogPack.pharmacy.stockMovements,
      `tenant:${tenant.id}`,
      tenantResult.pharmacy.stockMovements
    );
  }

  console.log('Clinical catalog seeded successfully.');

  return {
    skipped: false,
    summary: {
      ...clinicalCatalogPack.summary,
      additional_tenants_seeded: additionalTenants.length,
    },
  };
};

const main = async () => {
  try {
    await seedClinicalCatalogData({
      randomSeed: resolveNumericEnv(env.SEED_RANDOM_SEED, DEFAULT_RANDOM_SEED),
    });
  } catch (error) {
    console.error('Failed to seed clinical catalog:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  seedClinicalCatalogData,
};
