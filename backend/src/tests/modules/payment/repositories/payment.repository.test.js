/**
 * Payment repository tests
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  payment: {
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
} = require('@repositories/payment/payment.repository');

describe('Payment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should return payment by id', async () => {
      prisma.payment.findFirst.mockResolvedValue({ id: 'payment-1' });
      const result = await findById('payment-1');
      expect(result).toEqual({ id: 'payment-1' });
      expect(prisma.payment.findFirst).toHaveBeenCalledWith({
        where: { id: 'payment-1', deleted_at: null },
        include: {}
      });
    });

    it('should throw HttpError on db error', async () => {
      prisma.payment.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('payment-1')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should return payments list', async () => {
      prisma.payment.findMany.mockResolvedValue([{ id: 'payment-1' }]);
      const result = await findMany({ tenant_id: 'tenant-1' }, 0, 20, { created_at: 'desc' });
      expect(result).toEqual([{ id: 'payment-1' }]);
      expect(prisma.payment.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, tenant_id: 'tenant-1' },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count payments', async () => {
      prisma.payment.count.mockResolvedValue(3);
      const result = await count({ tenant_id: 'tenant-1' });
      expect(result).toBe(3);
      expect(prisma.payment.count).toHaveBeenCalledWith({
        where: { deleted_at: null, tenant_id: 'tenant-1' }
      });
    });
  });

  describe('create', () => {
    it('should create payment', async () => {
      const payload = {
        tenant_id: 'tenant-1',
        invoice_id: 'invoice-1',
        status: 'PENDING',
        method: 'CASH',
        amount: '120.00'
      };
      prisma.payment.create.mockResolvedValue({ id: 'payment-1', ...payload });
      const result = await create(payload);
      expect(result).toHaveProperty('id', 'payment-1');
      expect(prisma.payment.create).toHaveBeenCalledWith({ data: payload });
    });

    it('should map unique constraint error', async () => {
      const error = new Error('Unique');
      error.code = 'P2002';
      error.meta = { target: ['transaction_ref'] };
      prisma.payment.create.mockRejectedValue(error);
      await expect(create({})).rejects.toThrow(HttpError);
    });

    it('should map foreign key error', async () => {
      const error = new Error('Foreign key');
      error.code = 'P2003';
      error.meta = { field_name: 'invoice_id' };
      prisma.payment.create.mockRejectedValue(error);
      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update payment', async () => {
      prisma.payment.update.mockResolvedValue({ id: 'payment-1', status: 'COMPLETED' });
      const result = await update('payment-1', { status: 'COMPLETED' });
      expect(result).toEqual({ id: 'payment-1', status: 'COMPLETED' });
      expect(prisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'payment-1' },
        data: { status: 'COMPLETED' }
      });
    });

    it('should map not found error', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.payment.update.mockRejectedValue(error);
      await expect(update('missing', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete payment', async () => {
      prisma.payment.update.mockResolvedValue({ id: 'payment-1', deleted_at: new Date() });
      await softDelete('payment-1');
      expect(prisma.payment.update).toHaveBeenCalledWith({
        where: { id: 'payment-1' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});

