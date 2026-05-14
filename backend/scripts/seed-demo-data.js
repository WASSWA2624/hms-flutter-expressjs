/**
 * Curated demo seed orchestration.
 *
 * Usage:
 *   node scripts/seed-demo-data.js
 */

const {
  createSeedContext,
  DEFAULT_RANDOM_SEED,
  deterministicUuid,
  prisma,
} = require('./seeders/seed-runtime');
const env = require('@config/env');
const { seedOrgPack } = require('./seeders/seed-org-pack');
const { seedAccessPack } = require('./seeders/seed-access-pack');
const { seedClinicalCatalogPack } = require('./seeders/seed-clinical-catalog-pack');
const { seedClinicalPack } = require('./seeders/seed-clinical-pack');
const { seedOperationsPack } = require('./seeders/seed-operations-pack');
const { seedSubscriptionsPack } = require('./seeders/seed-subscriptions-pack');
const { seedCommunicationsPack } = require('./seeders/seed-communications-pack');
const { seedBiomedicalPack } = require('./seeders/seed-biomedical-pack');
const { seedMortuaryPack } = require('./seeders/seed-mortuary-pack');
const { seedCompliancePack } = require('./seeders/seed-compliance-pack');
const { seedGovernancePack } = require('./seeders/seed-governance-pack');
const { seedFillerPack } = require('./seeders/seed-filler-pack');
const { verifyDemoData } = require('./verify-demo-data');

const getDeterministicDate = (sequence = 0, minuteOffset = 0, randomSeed = DEFAULT_RANDOM_SEED) => {
  const seedOffsetMs = (Math.abs(Number(randomSeed) || DEFAULT_RANDOM_SEED) % 100000) * 1000;
  return new Date(Date.UTC(2026, 1, 15, 9, 0, 0) + seedOffsetMs + (sequence + minuteOffset) * 60000);
};

const resolveNumericEnv = (value, fallback) => {
  const parsed = Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const seedDemoData = async ({
  targetCount = 0,
  randomSeed = DEFAULT_RANDOM_SEED,
} = {}) => {
  if (env.NODE_ENV === 'production') {
    console.warn('Skipping seed: NODE_ENV=production');
    return { skipped: true, reason: 'production_environment' };
  }

  const ctx = createSeedContext({
    randomSeed,
    recordCount: targetCount,
  });

  console.log(`Seeding curated HMS demo data with random seed ${ctx.randomSeed}...`);

  const orgPack = await seedOrgPack(ctx);
  const accessPack = await seedAccessPack(ctx, orgPack);
  const subscriptionsPack = await seedSubscriptionsPack(ctx, orgPack);
  const clinicalCatalogPack = await seedClinicalCatalogPack(ctx, orgPack);
  const clinicalPack = await seedClinicalPack(ctx, orgPack, accessPack, clinicalCatalogPack);
  const operationsPack = await seedOperationsPack(ctx, orgPack, accessPack);
  const communicationsPack = await seedCommunicationsPack(ctx, orgPack, accessPack);
  const biomedicalPack = await seedBiomedicalPack(ctx, orgPack, accessPack, operationsPack);
  const mortuaryPack = await seedMortuaryPack(ctx, orgPack, accessPack, clinicalPack);
  const compliancePack = await seedCompliancePack(ctx, orgPack, accessPack, clinicalPack);
  const governancePack = await seedGovernancePack(
    ctx,
    orgPack,
    accessPack,
    clinicalPack,
    operationsPack
  );
  const fillerSummary = await seedFillerPack(ctx, targetCount);
  const verification = await verifyDemoData();

  if (!verification.ok) {
    throw new Error(`Demo data verification failed: ${verification.errors.join(' | ')}`);
  }

  console.log('Curated demo data seeded successfully.');

  return {
    skipped: false,
    summary: {
      tenants: Object.keys(orgPack.tenants).length,
      users: Object.keys(accessPack.users).length,
      subscriptions: Object.keys(subscriptionsPack.subscriptions).length,
      lab_catalog: {
        tenants: clinicalCatalogPack.summary.tenants,
        tests_per_tenant: clinicalCatalogPack.summary.lab_tests_per_tenant,
        panels_per_tenant: clinicalCatalogPack.summary.lab_panels_per_tenant,
      },
      clinical_catalog: clinicalCatalogPack.summary,
      patients: Object.keys(clinicalPack.patients).length,
      conversations: Object.keys(communicationsPack.conversations).length,
      biomedical_assets: Object.keys(biomedicalPack.registries).length,
      mortuary_cases: Object.keys(mortuaryPack.cases).length,
      filler: fillerSummary,
      compliance: Boolean(compliancePack.integration),
      governance: {
        abac_policies: Object.keys(governancePack.abacPolicies).length,
        break_glass_accesses: Object.keys(governancePack.breakGlassAccesses).length,
        break_glass_reviews: Object.keys(governancePack.breakGlassReviews).length,
        office_contexts: Object.keys(governancePack.officeContexts).length,
        shift_closes: Object.keys(governancePack.shiftCloses).length,
        day_closes: Object.keys(governancePack.dayCloses).length,
        handovers: Object.keys(governancePack.handovers).length,
        custody_snapshots: Object.keys(governancePack.custodySnapshots).length,
        closeout_packs: Object.keys(governancePack.closeoutPacks).length,
      },
    },
  };
};

const main = async () => {
  try {
    await seedDemoData({
      targetCount: 0,
      randomSeed: resolveNumericEnv(env.SEED_RANDOM_SEED, DEFAULT_RANDOM_SEED),
    });
  } catch (error) {
    console.error('Failed to seed demo data:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  seedDemoData,
  deterministicUuid,
  getDeterministicDate,
};
