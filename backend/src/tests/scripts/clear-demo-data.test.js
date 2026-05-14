const mockPrisma = {
  $queryRaw: jest.fn(),
  $executeRawUnsafe: jest.fn(),
  $transaction: jest.fn(async (callback) => callback(mockPrisma)),
  $disconnect: jest.fn(),
};

jest.mock('@prisma/client', () => mockPrisma);

describe('clear-demo-data script', () => {
  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
  });

  it('preserves prisma metadata and truncates application tables in sorted order', async () => {
    mockPrisma.$queryRaw.mockResolvedValue([
      { table_name: 'user' },
      { table_name: '_prisma_migrations' },
      { table_name: 'tenant' },
      { table_name: 'invoice' },
    ]);

    const { clearDemoData } = require('../../../scripts/clear-demo-data');
    await clearDemoData();

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
});
