jest.mock('@faker-js/faker', () => ({
  faker: {
    seed: jest.fn(),
    internet: { email: jest.fn(() => 'seed@example.local') },
    phone: { number: jest.fn(() => '+15550000000') },
    helpers: { slugify: jest.fn((value) => String(value).toLowerCase()) },
    person: { fullName: jest.fn(() => 'Seed User') },
    string: { alphanumeric: jest.fn(() => 'seedtokenvalue') },
    lorem: { sentence: jest.fn(() => 'Seed sentence.') }
  }
}));

const env = require('@config/env');

describe('seed-demo-data script', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'
    });
  });

  it('skips seeding in production environment', async () => {
    env.setEnvForTests({
      NODE_ENV: 'production',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'
    });

    jest.resetModules();
    const { seedDemoData } = require('../../../scripts/seed-demo-data');

    const result = await seedDemoData({
      skipDefaultAccounts: true
    });

    expect(result).toEqual({
      skipped: true,
      reason: 'production_environment'
    });
  });

  it('produces deterministic UUID output for identical input', () => {
    jest.resetModules();
    const { deterministicUuid } = require('../../../scripts/seed-demo-data');

    const first = deterministicUuid('seed:deterministic-check');
    const second = deterministicUuid('seed:deterministic-check');
    const third = deterministicUuid('seed:deterministic-check-other');

    expect(first).toBe(second);
    expect(third).not.toBe(first);
    expect(first).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-a[0-9a-f]{3}-[0-9a-f]{12}$/
    );
  });

  it('runs curated packs and skips filler when target count is zero', async () => {
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'
    });

    const seedOrgPack = jest.fn(async () => ({ tenants: { free: { id: 'tenant-free' } } }));
    const seedAccessPack = jest.fn(async () => ({ users: { 'free:superadmin': { id: 'user-1' } } }));
    const seedSubscriptionsPack = jest.fn(async () => ({ subscriptions: { free: { id: 'sub-1' } } }));
    const seedClinicalCatalogPack = jest.fn(async () => ({
      lab: { tests: {}, panels: {} },
      summary: {
        tenants: 1,
        lab_tests_per_tenant: 10,
        lab_panels_per_tenant: 2,
        radiology_tests_per_tenant: 18,
        drugs_per_tenant: 72,
        formulary_items_per_tenant: 72,
        inventory_items_per_tenant: 72,
        inventory_maps_per_tenant: 72,
        drug_batches_per_tenant: 72,
        facilities_seeded: 1,
        stock_records_seeded: 72,
        stock_movements_seeded: 72}}));
    const seedClinicalPack = jest.fn(async () => ({ patients: { 'free:p1': { id: 'patient-1' } } }));
    const seedOperationsPack = jest.fn(async () => ({ inventoryItems: {}, suppliers: {} }));
    const seedCommunicationsPack = jest.fn(async () => ({ conversations: { unreadDirect: { id: 'conv-1' } } }));
    const seedBiomedicalPack = jest.fn(async () => ({ registries: { pro: { id: 'eq-1' } } }));
    const seedMortuaryPack = jest.fn(async () => ({ cases: { demo: { id: 'mortuary-case-1' } } }));
    const seedCompliancePack = jest.fn(async () => ({ integration: { id: 'int-1' } }));
    const seedGovernancePack = jest.fn(async () => ({
      abacPolicies: { allowWardShift: { id: 'abp-1' }, denyPatientExport: { id: 'abp-2' } },
      breakGlassAccesses: { pending: { id: 'bga-1' }, active: { id: 'bga-2' } },
      breakGlassReviews: { approved: { id: 'bgr-1' } },
      officeContexts: { active: { id: 'ofc-1' } },
      shiftCloses: { approved: { id: 'scl-1' } },
      dayCloses: { approved: { id: 'dcl-1' } },
      handovers: { accepted: { id: 'hnd-1' } },
      custodySnapshots: { finalized: { id: 'cus-1' } },
      closeoutPacks: { ready: { id: 'clp-1' } }}));
    const seedFillerPack = jest.fn(async () => ({ skipped: true, reason: 'target_count_zero', created: 0, processed: 0 }));
    const seedVolumePack = jest.fn(async () => ({ skipped: true, reason: 'target_count_zero', targets: { skipped: true, highTraffic: 0, secondary: 0 }, created: {} }));
    const verifyDemoData = jest.fn(async () => ({ ok: true, errors: [], summary: {} }));

    jest.resetModules();
    jest.doMock('../../../scripts/seeders/seed-runtime', () => ({
      createSeedContext: jest.fn(() => ({
        randomSeed: 20260302,
        prisma: { $disconnect: jest.fn() }})),
      DEFAULT_RANDOM_SEED: 20260302,
      deterministicUuid: (value) => `uuid-${value}`,
      prisma: { $disconnect: jest.fn() }}));
    jest.doMock('../../../scripts/seeders/seed-org-pack', () => ({ seedOrgPack }));
    jest.doMock('../../../scripts/seeders/seed-access-pack', () => ({ seedAccessPack }));
    jest.doMock('../../../scripts/seeders/seed-subscriptions-pack', () => ({ seedSubscriptionsPack }));
    jest.doMock('../../../scripts/seeders/seed-clinical-catalog-pack', () => ({
      seedClinicalCatalogPack}));
    jest.doMock('../../../scripts/seeders/seed-clinical-pack', () => ({ seedClinicalPack }));
    jest.doMock('../../../scripts/seeders/seed-operations-pack', () => ({ seedOperationsPack }));
    jest.doMock('../../../scripts/seeders/seed-communications-pack', () => ({ seedCommunicationsPack }));
    jest.doMock('../../../scripts/seeders/seed-biomedical-pack', () => ({ seedBiomedicalPack }));
    jest.doMock('../../../scripts/seeders/seed-mortuary-pack', () => ({ seedMortuaryPack }));
    jest.doMock('../../../scripts/seeders/seed-compliance-pack', () => ({ seedCompliancePack }));
    jest.doMock('../../../scripts/seeders/seed-governance-pack', () => ({ seedGovernancePack }));
    jest.doMock('../../../scripts/seeders/seed-volume-pack', () => ({
      seedVolumePack,
      DEFAULT_DEMO_VOLUME_TARGET: 1000,
    }));
    jest.doMock('../../../scripts/seeders/seed-filler-pack', () => ({ seedFillerPack }));
    jest.doMock('../../../scripts/verify-demo-data', () => ({ verifyDemoData }));

    const { seedDemoData } = require('../../../scripts/seed-demo-data');
    const result = await seedDemoData({ targetCount: 0, randomSeed: 20260302 });

    expect(seedOrgPack).toHaveBeenCalledTimes(1);
    expect(seedAccessPack).toHaveBeenCalledTimes(1);
    expect(seedSubscriptionsPack).toHaveBeenCalledTimes(1);
    expect(seedClinicalCatalogPack).toHaveBeenCalledTimes(1);
    expect(seedClinicalPack).toHaveBeenCalledTimes(1);
    expect(seedOperationsPack).toHaveBeenCalledTimes(1);
    expect(seedCommunicationsPack).toHaveBeenCalledTimes(1);
    expect(seedBiomedicalPack).toHaveBeenCalledTimes(1);
    expect(seedMortuaryPack).toHaveBeenCalledTimes(1);
    expect(seedCompliancePack).toHaveBeenCalledTimes(1);
    expect(seedGovernancePack).toHaveBeenCalledTimes(1);
    expect(seedVolumePack).toHaveBeenCalledWith(
      expect.any(Object),
      0,
      expect.objectContaining({
        orgPack: expect.any(Object),
        accessPack: expect.any(Object),
        clinicalPack: expect.any(Object),
      })
    );
    expect(seedFillerPack).toHaveBeenCalledWith(expect.any(Object), 0, expect.any(Object));
    expect(verifyDemoData).toHaveBeenCalledTimes(1);
    expect(result.skipped).toBe(false);
    expect(result.summary.target_count).toBe(0);
    expect(result.summary.lab_catalog).toEqual({
      tenants: 1,
      tests_per_tenant: 10,
      panels_per_tenant: 2
    });
    expect(result.summary.clinical_catalog).toEqual({
      tenants: 1,
      lab_tests_per_tenant: 10,
      lab_panels_per_tenant: 2,
      radiology_tests_per_tenant: 18,
      drugs_per_tenant: 72,
      formulary_items_per_tenant: 72,
      inventory_items_per_tenant: 72,
      inventory_maps_per_tenant: 72,
      drug_batches_per_tenant: 72,
      facilities_seeded: 1,
      stock_records_seeded: 72,
      stock_movements_seeded: 72
    });
    expect(result.summary.volume).toEqual({
      skipped: true,
      reason: 'target_count_zero',
      targets: { skipped: true, highTraffic: 0, secondary: 0 },
      created: {},
    });
    expect(result.summary.filler).toEqual({
      skipped: true,
      reason: 'target_count_zero',
      created: 0,
      processed: 0
    });
    expect(result.summary.governance).toEqual({
      abac_policies: 2,
      break_glass_accesses: 2,
      break_glass_reviews: 1,
      office_contexts: 1,
      shift_closes: 1,
      day_closes: 1,
      handovers: 1,
      custody_snapshots: 1,
      closeout_packs: 1
    });
  });

  it('resolves default volume target when SEED_RECORD_COUNT is unset', () => {
    jest.resetModules();
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
      SEED_RECORD_COUNT: 1000,
    });
    jest.doMock('../../../scripts/seeders/seed-volume-pack', () => ({
      seedVolumePack: jest.fn(),
      DEFAULT_DEMO_VOLUME_TARGET: 1000,
    }));
    const { resolveDemoTargetCount, DEFAULT_DEMO_VOLUME_TARGET } = require('../../../scripts/seed-demo-data');
    expect(resolveDemoTargetCount(undefined)).toBe(DEFAULT_DEMO_VOLUME_TARGET);
    expect(resolveDemoTargetCount(0)).toBe(0);
    expect(resolveDemoTargetCount(250)).toBe(250);
  });

  it('runs volume pack when target count is positive', async () => {
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
      SEED_RECORD_COUNT: 100,
    });

    const seedOrgPack = jest.fn(async () => ({ tenants: { demo: { id: 't1' } }, facilities: { 'demo:main': { id: 'f1', tenant_id: 't1' } } }));
    const seedAccessPack = jest.fn(async () => ({ users: {} }));
    const seedSubscriptionsPack = jest.fn(async () => ({ subscriptions: {} }));
    const seedClinicalCatalogPack = jest.fn(async () => ({
      lab: { tests: {} },
      summary: {
        tenants: 1,
        lab_tests_per_tenant: 1,
        lab_panels_per_tenant: 1,
        radiology_tests_per_tenant: 1,
        drugs_per_tenant: 1,
        formulary_items_per_tenant: 1,
        inventory_items_per_tenant: 1,
        inventory_maps_per_tenant: 1,
        drug_batches_per_tenant: 1,
        facilities_seeded: 1,
        stock_records_seeded: 1,
        stock_movements_seeded: 1,
      },
    }));
    const seedClinicalPack = jest.fn(async () => ({ patients: {} }));
    const seedOperationsPack = jest.fn(async () => ({ inventoryItems: {} }));
    const seedCommunicationsPack = jest.fn(async () => ({ conversations: {} }));
    const seedBiomedicalPack = jest.fn(async () => ({ registries: {} }));
    const seedMortuaryPack = jest.fn(async () => ({ cases: {} }));
    const seedCompliancePack = jest.fn(async () => ({ integration: { id: 'int-1' } }));
    const seedGovernancePack = jest.fn(async () => ({
      abacPolicies: {},
      breakGlassAccesses: {},
      breakGlassReviews: {},
      officeContexts: {},
      shiftCloses: {},
      dayCloses: {},
      handovers: {},
      custodySnapshots: {},
      closeoutPacks: {},
    }));
    const seedVolumePack = jest.fn(async () => ({
      skipped: false,
      targets: { skipped: false, highTraffic: 100, secondary: 100 },
      created: { patients: 100 },
      patients: 100,
    }));
    const seedFillerPack = jest.fn(async () => ({ skipped: false, created: 0, processed: 0 }));
    const verifyDemoData = jest.fn(async () => ({ ok: true, errors: [], summary: {} }));

    jest.resetModules();
    jest.doMock('../../../scripts/seeders/seed-runtime', () => ({
      createSeedContext: jest.fn(() => ({ randomSeed: 20260302 })),
      DEFAULT_RANDOM_SEED: 20260302,
      deterministicUuid: (value) => `uuid-${value}`,
      prisma: { $disconnect: jest.fn() },
    }));
    jest.doMock('../../../scripts/seeders/seed-org-pack', () => ({ seedOrgPack }));
    jest.doMock('../../../scripts/seeders/seed-access-pack', () => ({ seedAccessPack }));
    jest.doMock('../../../scripts/seeders/seed-subscriptions-pack', () => ({ seedSubscriptionsPack }));
    jest.doMock('../../../scripts/seeders/seed-clinical-catalog-pack', () => ({ seedClinicalCatalogPack }));
    jest.doMock('../../../scripts/seeders/seed-clinical-pack', () => ({ seedClinicalPack }));
    jest.doMock('../../../scripts/seeders/seed-operations-pack', () => ({ seedOperationsPack }));
    jest.doMock('../../../scripts/seeders/seed-communications-pack', () => ({ seedCommunicationsPack }));
    jest.doMock('../../../scripts/seeders/seed-biomedical-pack', () => ({ seedBiomedicalPack }));
    jest.doMock('../../../scripts/seeders/seed-mortuary-pack', () => ({ seedMortuaryPack }));
    jest.doMock('../../../scripts/seeders/seed-compliance-pack', () => ({ seedCompliancePack }));
    jest.doMock('../../../scripts/seeders/seed-governance-pack', () => ({ seedGovernancePack }));
    jest.doMock('../../../scripts/seeders/seed-volume-pack', () => ({
      seedVolumePack,
      DEFAULT_DEMO_VOLUME_TARGET: 1000,
    }));
    jest.doMock('../../../scripts/seeders/seed-filler-pack', () => ({ seedFillerPack }));
    jest.doMock('../../../scripts/verify-demo-data', () => ({ verifyDemoData }));

    const { seedDemoData } = require('../../../scripts/seed-demo-data');
    const result = await seedDemoData({ targetCount: 100, randomSeed: 20260302 });

    expect(seedVolumePack).toHaveBeenCalledWith(expect.any(Object), 100, expect.any(Object));
    expect(seedFillerPack).not.toHaveBeenCalled();
    expect(result.summary.target_count).toBe(100);
    expect(result.summary.volume.skipped).toBe(false);
    expect(result.summary.filler).toEqual({
      skipped: true,
      reason: 'volume_pack_satisfies_applicable_targets',
      created: 0,
      processed: 0,
    });
  });
});
