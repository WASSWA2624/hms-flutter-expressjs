/**
 * Refund repository tests
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  refund: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const prisma = require('@prisma/client');
const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/refund/refund.repository');

describe('Refund Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should return refund by id', async () => {
      prisma.refund.findFirst.mockResolvedValue({ id: 'refund-1' });
      const result = await findById('refund-1');
      expect(result).toEqual({ id: 'refund-1' });
      expect(prisma.refund.findFirst).toHaveBeenCalledWith({
        where: { id: 'refund-1', deleted_at: null },
        include: {}
      });
    });

    it('should throw HttpError on db error', async () => {
      prisma.refund.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('refund-1')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should return refunds list', async () => {
      prisma.refund.findMany.mockResolvedValue([{ id: 'refund-1' }]);
      const result = await findMany({ payment_id: 'payment-1' }, 0, 20, { refunded_at: 'desc' });
      expect(result).toEqual([{ id: 'refund-1' }]);
      expect(prisma.refund.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, payment_id: 'payment-1' },
        skip: 0,
        take: 20,
        orderBy: { refunded_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count refunds', async () => {
      prisma.refund.count.mockResolvedValue(2);
      const result = await count({ payment_id: 'payment-1' });
      expect(result).toBe(2);
      expect(prisma.refund.count).toHaveBeenCalledWith({
        where: { deleted_at: null, payment_id: 'payment-1' }
      });
    });
  });

  describe('create', () => {
    it('should create refund', async () => {
      const payload = { payment_id: 'payment-1', amount: '10.00' };
      prisma.refund.create.mockResolvedValue({ id: 'refund-1', ...payload });
      const result = await create(payload);
      expect(result).toHaveProperty('id', 'refund-1');
      expect(prisma.refund.create).toHaveBeenCalledWith({ data: payload });
    });

    it('should map foreign key error', async () => {
      const error = new Error('FK');
      error.code = 'P2003';
      error.meta = { field_name: 'payment_id' };
      prisma.refund.create.mockRejectedValue(error);
      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update refund', async () => {
      prisma.refund.update.mockResolvedValue({ id: 'refund-1', reason: 'Updated' });
      const result = await update('refund-1', { reason: 'Updated' });
      expect(result).toEqual({ id: 'refund-1', reason: 'Updated' });
      expect(prisma.refund.update).toHaveBeenCalledWith({
        where: { id: 'refund-1' },
        data: { reason: 'Updated' }
      });
    });

    it('should map not found error', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.refund.update.mockRejectedValue(error);
      await expect(update('missing', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete refund', async () => {
      prisma.refund.update.mockResolvedValue({ id: 'refund-1', deleted_at: new Date() });
      await softDelete('refund-1');
      expect(prisma.refund.update).toHaveBeenCalledWith({
        where: { id: 'refund-1' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});

