const theatreFlowRepository = require('@repositories/theatre-flow/theatre-flow.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  theatre_case: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
  },
}));

describe('theatre-flow.repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('findById reads active theatre case', async () => {
    prisma.theatre_case.findFirst.mockResolvedValue({ id: 'TC-001' });
    const result = await theatreFlowRepository.findById('TC-001');
    expect(result).toEqual({ id: 'TC-001' });
    expect(prisma.theatre_case.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ id: 'TC-001', deleted_at: null }),
      })
    );
  });

  it('findMany applies pagination and filters', async () => {
    prisma.theatre_case.findMany.mockResolvedValue([{ id: 'TC-001' }]);
    const result = await theatreFlowRepository.findMany({ status: 'SCHEDULED' }, 0, 10);
    expect(result).toEqual([{ id: 'TC-001' }]);
    expect(prisma.theatre_case.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: 'SCHEDULED', deleted_at: null }),
        skip: 0,
        take: 10,
      })
    );
  });

  it('count returns total rows', async () => {
    prisma.theatre_case.count.mockResolvedValue(12);
    const result = await theatreFlowRepository.count({ status: 'IN_PROGRESS' });
    expect(result).toBe(12);
  });

  it('wraps prisma errors as HttpError', async () => {
    prisma.theatre_case.findMany.mockRejectedValue(new Error('db-fail'));
    await expect(theatreFlowRepository.findMany()).rejects.toThrow(HttpError);
  });
});

