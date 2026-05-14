jest.mock('@prisma/client', () => ({
  lab_order: {
    findMany: jest.fn(),
    count: jest.fn(),
    findFirst: jest.fn(),
  },
  lab_order_item: {
    count: jest.fn(),
  },
  lab_sample: {
    count: jest.fn(),
  },
  lab_result: {
    count: jest.fn(),
  },
  $transaction: jest.fn(),
}));

const prisma = require('@prisma/client');
const subject = require('@repositories/lab-workspace/lab-workspace.repository');

describe('lab-workspace.repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('findManyOrders applies soft-delete protection and query options', async () => {
    prisma.lab_order.findMany.mockResolvedValue([]);

    await subject.findManyOrders(
      { status: 'ORDERED' },
      10,
      25,
      { ordered_at: 'desc' },
      { patient: true }
    );

    expect(prisma.lab_order.findMany).toHaveBeenCalledWith({
      where: {
        deleted_at: null,
        status: 'ORDERED',
      },
      skip: 10,
      take: 25,
      orderBy: { ordered_at: 'desc' },
      include: { patient: true },
    });
  });

  it('countResults applies soft-delete protection', async () => {
    prisma.lab_result.count.mockResolvedValue(3);

    await subject.countResults({ status: 'CRITICAL' });

    expect(prisma.lab_result.count).toHaveBeenCalledWith({
      where: {
        deleted_at: null,
        status: 'CRITICAL',
      },
    });
  });

  it('withTransaction delegates to prisma.$transaction', async () => {
    prisma.$transaction.mockImplementation(async (callback) => callback({ tx: true }));

    const result = await subject.withTransaction(async (tx) => tx);

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(result).toEqual({ tx: true });
  });
});
