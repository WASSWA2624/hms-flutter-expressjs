const env = require('@config/env');

const mockPrisma = { $disconnect: jest.fn() };
const mockCreateSeedContext = jest.fn(() => ({ randomSeed: 20260302 }));
const mockSeedOrgPack = jest.fn(async () => ({ tenants: { demo: { id: 'tenant-demo' } } }));
const mockSeedAccessPack = jest.fn(async () => ({
  users: {
    doctor: { id: 'user-doctor' },
    nurse: { id: 'user-nurse' },
  },
}));

jest.mock('../../../scripts/seeders/seed-runtime', () => ({
  createSeedContext: mockCreateSeedContext,
  DEFAULT_RANDOM_SEED: 20260302,
  prisma: mockPrisma,
}));

jest.mock('../../../scripts/seeders/seed-org-pack', () => ({
  seedOrgPack: mockSeedOrgPack,
}));

jest.mock('../../../scripts/seeders/seed-access-pack', () => ({
  seedAccessPack: mockSeedAccessPack,
}));

describe('setup-default-accounts script', () => {
  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });
  });

  it('sets up demo tenants and users without returning the shared password', async () => {
    const { setupDefaultAccounts } = require('../../../scripts/setup-default-accounts');

    const result = await setupDefaultAccounts();

    expect(result).toEqual({
      skipped: false,
      tenants: ['demo'],
      users: ['doctor', 'nurse'],
    });
    expect(result.defaultPassword).toBeUndefined();
    expect(mockSeedOrgPack).toHaveBeenCalledTimes(1);
    expect(mockSeedAccessPack).toHaveBeenCalledTimes(1);
  });

  it('skips account setup in production', async () => {
    env.setEnvForTests({
      NODE_ENV: 'production',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    const { setupDefaultAccounts } = require('../../../scripts/setup-default-accounts');
    const result = await setupDefaultAccounts();

    expect(result).toEqual({ skipped: true, reason: 'production_environment' });
    expect(mockSeedOrgPack).not.toHaveBeenCalled();
    expect(mockSeedAccessPack).not.toHaveBeenCalled();
  });
});
