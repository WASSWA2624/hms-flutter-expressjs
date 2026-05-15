const mockPrisma = {
  $queryRaw: jest.fn(),
  $executeRawUnsafe: jest.fn(),
  $transaction: jest.fn(async (callback) => callback(mockPrisma)),
  $disconnect: jest.fn(),
};

jest.mock('@prisma/client', () => mockPrisma);

const env = require('@config/env');

describe('clear-demo-data script', () => {
  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'
    });
  });

  it('preserves prisma metadata and truncates application tables in sorted order', async () => {
    mockPrisma.$queryRaw.mockResolvedValue([
      { table_name: 'user' },
      { table_name: '_prisma_migrations' },
      { table_name: 'tenant' },
      { table_name: 'invoice' },
    ]);

    const { clearDemoData } = require('../../../scripts/clear-demo-data');
    await clearDemoData({ confirm: true });

    expect(mockPrisma.$executeRawUnsafe).toHaveBeenNthCalledWith(1, 'SET FOREIGN_KEY_CHECKS = 0');
    expect(mockPrisma.$executeRawUnsafe).toHaveBeenNthCalledWith(2, 'DELETE FROM `invoice`');
    expect(mockPrisma.$executeRawUnsafe).toHaveBeenNthCalledWith(3, 'DELETE FROM `tenant`');
    expect(mockPrisma.$executeRawUnsafe).toHaveBeenNthCalledWith(4, 'DELETE FROM `user`');
    expect(mockPrisma.$executeRawUnsafe).toHaveBeenNthCalledWith(5, 'SET FOREIGN_KEY_CHECKS = 1');
    expect(mockPrisma.$executeRawUnsafe).not.toHaveBeenCalledWith('DELETE FROM `_prisma_migrations`');
  });

  it('supports dry-run without deleting data', async () => {
    mockPrisma.$queryRaw.mockResolvedValue([
      { table_name: '_prisma_migrations' },
      { table_name: 'conversation' },
      { table_name: 'notification' },
    ]);

    const { clearDemoData } = require('../../../scripts/clear-demo-data');
    await clearDemoData({ dryRun: true });

    expect(mockPrisma.$executeRawUnsafe).not.toHaveBeenCalled();
    expect(console.log).toHaveBeenCalledWith('Dry run mode: the following tables would be cleared:');
    expect(console.log).toHaveBeenCalledWith('  - conversation');
    expect(console.log).toHaveBeenCalledWith('  - notification');
  });

  it('refuses destructive clears without explicit confirmation', async () => {
    mockPrisma.$queryRaw.mockResolvedValue([{ table_name: 'tenant' }]);

    const { clearDemoData } = require('../../../scripts/clear-demo-data');

    await expect(clearDemoData()).rejects.toThrow('explicit confirmation');
    expect(mockPrisma.$executeRawUnsafe).not.toHaveBeenCalled();
  });

  it('skips clearing data in production', async () => {
    env.setEnvForTests({
      NODE_ENV: 'production',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'
    });

    const { clearDemoData } = require('../../../scripts/clear-demo-data');
    const result = await clearDemoData({ confirm: true });

    expect(result).toEqual({ skipped: true, reason: 'production_environment' });
    expect(mockPrisma.$queryRaw).not.toHaveBeenCalled();
    expect(mockPrisma.$executeRawUnsafe).not.toHaveBeenCalled();
  });
});
