jest.mock('@faker-js/faker', () => ({
  faker: {
    seed: jest.fn(),
  },
}));

const env = require('@config/env');

describe('seed-clinical-catalog-data script', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });
  });

  it('skips clinical catalog seeding in production', async () => {
    env.setEnvForTests({
      NODE_ENV: 'production',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    jest.resetModules();
    const { seedClinicalCatalogData } = require('../../../scripts/seed-clinical-catalog-data');

    const result = await seedClinicalCatalogData();

    expect(result).toEqual({
      skipped: true,
      reason: 'production_environment',
    });
  });

  it('creates the seed context, seeds demo org data, and backfills existing tenants', async () => {
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    const seedOrgPack = jest.fn(async () => ({
      tenants: { pro: { id: 'tenant-pro' } },
      facilities: {
        'pro:main': { id: 'facility-main', tenant_id: 'tenant-pro' },
        'pro:diag': { id: 'facility-diag', tenant_id: 'tenant-pro' },
      },
    }));
    const seedClinicalCatalogPack = jest.fn(async () => ({
      lab: { tests: {}, panels: {} },
      radiology: { tests: {} },
      pharmacy: {
        drugs: {},
        formularyItems: {},
        inventoryItems: {},
        inventoryMaps: {},
        drugBatches: {},
        inventoryStocks: {},
        stockMovements: {},
      },
      summary: {
        tenants: 1,
        facilities_seeded: 2,
        lab_tests_per_tenant: 66,
        lab_panels_per_tenant: 19,
        radiology_tests_per_tenant: 44,
        drugs_per_tenant: 83,
        formulary_items_per_tenant: 83,
        inventory_items_per_tenant: 83,
        inventory_maps_per_tenant: 83,
        drug_batches_per_tenant: 83,
        stock_records_seeded: 166,
        stock_movements_seeded: 166,
      },
    }));
    const seedClinicalCatalogForTenant = jest.fn(async () => ({
      lab: { tests: { hemoglobin: { id: 'test-1' } }, panels: { cbc: { id: 'panel-1' } } },
      radiology: { tests: { chest: { id: 'rad-1' } } },
      pharmacy: {
        drugs: { amoxicillin: { id: 'drug-1' } },
        formularyItems: { amoxicillin: { id: 'form-1' } },
        inventoryItems: { amoxicillin: { id: 'inv-1' } },
        inventoryMaps: { amoxicillin: { id: 'map-1' } },
        drugBatches: { amoxicillin: { id: 'batch-1' } },
        inventoryStocks: { 'amoxicillin:facility-live': { id: 'stock-1' } },
        stockMovements: { 'amoxicillin:facility-live': { id: 'move-1' } },
      },
    }));

    jest.resetModules();
    jest.doMock('../../../scripts/seeders/seed-runtime', () => ({
      createSeedContext: jest.fn(() => ({
        randomSeed: 20260313,
      })),
      DEFAULT_RANDOM_SEED: 20260302,
      prisma: {
        $disconnect: jest.fn(),
        tenant: {
          findMany: jest.fn(async () => [
            {
              id: 'tenant-live',
              human_friendly_id: 'TEN-LIVE',
              name: 'Live Hospital',
              facilities: [{ id: 'facility-live' }],
            },
          ]),
        },
      },
    }));
    jest.doMock('../../../scripts/seeders/seed-org-pack', () => ({ seedOrgPack }));
    jest.doMock('../../../scripts/seeders/seed-clinical-catalog-pack', () => ({
      seedClinicalCatalogPack,
      seedClinicalCatalogForTenant,
    }));

    const { seedClinicalCatalogData } = require('../../../scripts/seed-clinical-catalog-data');
    const result = await seedClinicalCatalogData({ randomSeed: 20260313 });

    expect(seedOrgPack).toHaveBeenCalledTimes(1);
    expect(seedClinicalCatalogPack).toHaveBeenCalledTimes(1);
    expect(seedClinicalCatalogPack).toHaveBeenCalledWith(
      expect.objectContaining({ randomSeed: 20260313 }),
      expect.objectContaining({
        tenants: expect.any(Object),
        facilities: expect.any(Object),
      })
    );
    expect(seedClinicalCatalogForTenant).toHaveBeenCalledTimes(1);
    expect(seedClinicalCatalogForTenant).toHaveBeenCalledWith(
      expect.objectContaining({ randomSeed: 20260313 }),
      expect.objectContaining({
        seedKey: 'tenant:tenant-live',
        tenantId: 'tenant-live',
        tenantCode: 'TEN-LIVE',
        scenarioKey: 'EXISTING',
        facilityIds: ['facility-live'],
      })
    );
    expect(result).toEqual({
      skipped: false,
      summary: {
        tenants: 2,
        facilities_seeded: 3,
        lab_tests_per_tenant: 66,
        lab_panels_per_tenant: 19,
        radiology_tests_per_tenant: 44,
        drugs_per_tenant: 83,
        formulary_items_per_tenant: 83,
        inventory_items_per_tenant: 83,
        inventory_maps_per_tenant: 83,
        drug_batches_per_tenant: 83,
        stock_records_seeded: 167,
        stock_movements_seeded: 167,
        additional_tenants_seeded: 1,
      },
    });
  });
});
