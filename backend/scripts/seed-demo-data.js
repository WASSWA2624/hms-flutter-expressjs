/**
 * Curated demo seed orchestration.
 *
 * Usage:
 *   node scripts/seed-demo-data.js
 *   SEED_RECORD_COUNT=0 node scripts/seed-demo-data.js   # curated-only
 *   SEED_RECORD_COUNT=1000 node scripts/seed-demo-data.js
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
const {
  DEFAULT_DEMO_VOLUME_TARGET,
  seedVolumePack,
} = require('./seeders/seed-volume-pack');
const { seedVolumeExtendedPack } = require('./seeders/seed-volume-extended-pack');
const { seedFillerPack } = require('./seeders/seed-filler-pack');
const { assertDemoTaskAllowed } = require('./demo-safety');
const { verifyDemoData } = require('./verify-demo-data');

try {
  const { stopBreakGlassExpiryRuntime } = require('@lib/authorization/break-glass-expiry');
  stopBreakGlassExpiryRuntime();
} catch (_error) {
  // Optional during seed; ignore if the runtime module is unavailable.
}

const getDeterministicDate = (sequence = 0, minuteOffset = 0, randomSeed = DEFAULT_RANDOM_SEED) => {
  const seedOffsetMs = (Math.abs(Number(randomSeed) || DEFAULT_RANDOM_SEED) % 100000) * 1000;
  return new Date(Date.UTC(2026, 1, 15, 9, 0, 0) + seedOffsetMs + (sequence + minuteOffset) * 60000);
};

const resolveNumericEnv = (value, fallback) => {
  const parsed = Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

/**
 * Resolve volume target for demo seed.
 * - Explicit options.targetCount wins
 * - SEED_RECORD_COUNT=0 → curated-only (skip volume + filler)
 * - unset / invalid → DEFAULT_DEMO_VOLUME_TARGET (1000)
 */
const resolveDemoTargetCount = (explicitTarget) => {
  if (explicitTarget !== undefined && explicitTarget !== null) {
    const parsed = Number.parseInt(String(explicitTarget), 10);
    return Number.isFinite(parsed) ? parsed : DEFAULT_DEMO_VOLUME_TARGET;
  }
  if (process.env.SEED_RECORD_COUNT !== undefined && process.env.SEED_RECORD_COUNT !== '') {
    return resolveNumericEnv(process.env.SEED_RECORD_COUNT, DEFAULT_DEMO_VOLUME_TARGET);
  }
  if (env.SEED_RECORD_COUNT !== undefined && env.SEED_RECORD_COUNT !== null) {
    return resolveNumericEnv(env.SEED_RECORD_COUNT, DEFAULT_DEMO_VOLUME_TARGET);
  }
  return DEFAULT_DEMO_VOLUME_TARGET;
};

const seedDemoData = async ({
  targetCount,
  randomSeed = DEFAULT_RANDOM_SEED,
} = {}) => {
  const safety = assertDemoTaskAllowed('demo seed');
  if (!safety.allowed) {
    console.warn('Skipping seed: NODE_ENV=production');
    return { skipped: true, reason: safety.reason };
  }

  const resolvedTargetCount = resolveDemoTargetCount(targetCount);

  const ctx = createSeedContext({
    randomSeed,
    recordCount: resolvedTargetCount,
  });

  console.log(
    `Seeding curated HMS demo data with random seed ${ctx.randomSeed} (volume target ${resolvedTargetCount})...`
  );

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
  const volumeSummary = await seedVolumePack(ctx, resolvedTargetCount, {
    orgPack,
    accessPack,
    clinicalPack,
    clinicalCatalogPack,
    operationsPack,
    biomedicalPack,
    mortuaryPack,
  });
  const volumeExtendedSummary = await seedVolumeExtendedPack(ctx, resolvedTargetCount, {
    orgPack,
    accessPack,
    operationsPack,
    clinicalCatalogPack,
    volumeSummary,
    communicationsPack,
  });

  const demoFacility = orgPack.facilities?.[`${Object.keys(orgPack.tenants || {})[0] || 'demo'}:main`]
    || Object.values(orgPack.facilities || {})[0];
  const demoTenantId = demoFacility?.tenant_id || Object.values(orgPack.tenants || {})[0]?.id;
  const patientIds = [
    ...Object.values(clinicalPack?.patients || {}).map((patient) => patient.id),
    ...(volumeSummary.patient_ids || []),
  ].filter(Boolean);
  const userIds = Object.values(accessPack?.users || {}).map((user) => user.id).filter(Boolean);
  const staffProfileIds = Object.values(accessPack?.staffProfiles || {})
    .map((profile) => profile.id)
    .filter(Boolean);
  const inventoryItemIds = [
    ...Object.values(clinicalCatalogPack?.pharmacy?.inventoryItems || {}).map((item) => item.id),
    ...Object.values(operationsPack?.inventoryItems || {}).map((item) => item.id),
  ].filter(Boolean);
  const equipmentRegistryId =
    biomedicalPack?.registries?.[Object.keys(biomedicalPack?.registries || {})[0]]?.id
    || Object.values(biomedicalPack?.registries || {})[0]?.id
    || null;

  const fillerSummary = volumeSummary.skipped
    ? await seedFillerPack(ctx, resolvedTargetCount, {
        tenant_id: demoTenantId,
        facility_id: demoFacility?.id || null,
        patient_ids: patientIds,
        user_ids: userIds,
        staff_profile_ids: staffProfileIds,
        inventory_item_ids: inventoryItemIds,
        inventory_item_id: inventoryItemIds[0] || null,
        equipment_registry_id: equipmentRegistryId,
        equipment_registry_ids: equipmentRegistryId ? [equipmentRegistryId] : [],
      })
    : {
        skipped: true,
        reason: 'volume_pack_satisfies_applicable_targets',
        created: 0,
        processed: 0,
      };

  // Heal hero break-glass ACTIVE row in case an expiry sweep flipped it during long volume seeding.
  if (demoTenantId && prisma.break_glass_access?.updateMany) {
    await prisma.break_glass_access.updateMany({
      where: {
        tenant_id: demoTenantId,
        review_status: 'APPROVED',
        deleted_at: null,
      },
      data: {
        status: 'ACTIVE',
        expires_at: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000),
      },
    });
  }

  const verification = await verifyDemoData();

  if (!verification.ok) {
    throw new Error(`Demo data verification failed: ${verification.errors.join(' | ')}`);
  }

  console.log('Curated demo data seeded successfully.');

  return {
    skipped: false,
    summary: {
      target_count: resolvedTargetCount,
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
      volume: volumeSummary,
      volume_extended: volumeExtendedSummary,
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
  resolveDemoTargetCount,
  DEFAULT_DEMO_VOLUME_TARGET,
};
