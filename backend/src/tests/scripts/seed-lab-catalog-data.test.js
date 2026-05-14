jest.mock('@faker-js/faker', () => ({
  faker: {
    seed: jest.fn(),
  },
}));

const env = require('@config/env');

describe('seed-lab-catalog-data script', () => {
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

  it('skips lab catalog seeding in production', async () => {
    env.setEnvForTests({
      NODE_ENV: 'production',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    jest.resetModules();
    const { seedLabCatalogData } = require('../../../scripts/seed-lab-catalog-data');

    const result = await seedLabCatalogData();

    expect(result).toEqual({
      skipped: true,
      reason: 'production_environment',
    });
  });

  it('creates the seed context, upserts org data, and returns the catalog summary', async () => {
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    const seedOrgPack = jest.fn(async () => ({
      tenants: { pro: { id: 'tenant-pro' } },
      facilities: { 'pro:main': { id: 'facility-main', tenant_id: 'tenant-pro' } },
    }));
    const seedLabCatalogPack = jest.fn(async () => ({
      tests: {},
      panels: {},
      summary: {
        tenants: 1,
        tests_per_tenant: 66,
        panels_per_tenant: 19,
      },
    }));
    const seedLabCatalogForTenant = jest.fn(async () => ({
      tests: { hemoglobin: { id: 'test-1' } },
      panels: { cbc: { id: 'panel-1' } },
    }));

    jest.resetModules();
    jest.doMock('../../../scripts/seeders/seed-runtime', () => ({
      createSeedContext: jest.fn(() => ({
        randomSeed: 20260312,
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
            },
          ]),
        },
      },
    }));
    jest.doMock('../../../scripts/seeders/seed-org-pack', () => ({ seedOrgPack }));
    jest.doMock('../../../scripts/seeders/seed-lab-catalog-pack', () => ({
      LAB_TEST_CATALOG: new Array(66).fill({}),
      LAB_PANEL_CATALOG: new Array(19).fill({}),
      seedLabCatalogPack,
      seedLabCatalogForTenant,
    }));

    const { seedLabCatalogData } = require('../../../scripts/seed-lab-catalog-data');
    const result = await seedLabCatalogData({ randomSeed: 20260312 });

    expect(seedOrgPack).toHaveBeenCalledTimes(1);
    expect(seedLabCatalogPack).toHaveBeenCalledTimes(1);
    expect(seedLabCatalogPack).toHaveBeenCalledWith(
      expect.objectContaining({ randomSeed: 20260312 }),
      expect.objectContaining({
        tenants: expect.any(Object),
        facilities: expect.any(Object),
      })
    );
    expect(seedLabCatalogForTenant).toHaveBeenCalledTimes(1);
    expect(seedLabCatalogForTenant).toHaveBeenCalledWith(
      expect.objectContaining({ randomSeed: 20260312 }),
      expect.objectContaining({
        seedKey: 'tenant:tenant-live',
        tenantId: 'tenant-live',
        tenantCode: 'TEN-LIVE',
        scenarioKey: 'EXISTING',
      })
    );
    expect(result).toEqual({
      skipped: false,
      summary: {
        tenants: 2,
        tests_per_tenant: 66,
        panels_per_tenant: 19,
        additional_tenants_seeded: 1,
      },
    });
  });
});
