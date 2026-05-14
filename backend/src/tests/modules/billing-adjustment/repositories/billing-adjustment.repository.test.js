/**
 * Billing Adjustment repository tests
 *
 * @module tests/modules/billing-adjustment/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  billing_adjustment: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/billing-adjustment/billing-adjustment.repository');

const prisma = require('@prisma/client');

describe('Billing Adjustment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find billing adjustment by ID', async () => {
      const mockBillingAdjustment = {
        id: 'adjustment-123',
        invoice_id: 'invoice-123',
        amount: 100.50,
        status: 'DRAFT',
        reason: 'Discount applied',
        adjusted_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.billing_adjustment.findFirst.mockResolvedValue(mockBillingAdjustment);

      const result = await findById('adjustment-123');

      expect(result).toEqual(mockBillingAdjustment);
      expect(prisma.billing_adjustment.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'adjustment-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if billing adjustment not found', async () => {
      prisma.billing_adjustment.findFirst.mockResolvedValue(null);

      const result = await findById('adjustment-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.billing_adjustment.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('adjustment-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockBillingAdjustment = { id: 'adjustment-123' };
      prisma.billing_adjustment.findFirst.mockResolvedValue(mockBillingAdjustment);

      await findById('adjustment-123', { invoice: true });

      expect(prisma.billing_adjustment.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'adjustment-123',
          deleted_at: null
        },
        include: { invoice: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find many billing adjustments with default pagination', async () => {
      const mockBillingAdjustments = [
        {
          id: 'adjustment-1',
          invoice_id: 'invoice-123',
          amount: 100.50,
          status: 'DRAFT',
          reason: 'Discount applied'
        },
        {
          id: 'adjustment-2',
          invoice_id: 'invoice-456',
          amount: 50.25,
          status: 'PAID',
          reason: 'Tax adjustment'
        }
      ];
      prisma.billing_adjustment.findMany.mockResolvedValue(mockBillingAdjustments);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockBillingAdjustments);
      expect(prisma.billing_adjustment.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find billing adjustments with filters', async () => {
      const mockBillingAdjustments = [
        {
          id: 'adjustment-1',
          invoice_id: 'invoice-123',
          amount: 100.50,
          status: 'DRAFT'
        }
      ];
      prisma.billing_adjustment.findMany.mockResolvedValue(mockBillingAdjustments);

      const result = await findMany({ 
        invoice_id: 'invoice-123', 
        status: 'DRAFT'
      }, 0, 10);

      expect(result).toEqual(mockBillingAdjustments);
      expect(prisma.billing_adjustment.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          invoice_id: 'invoice-123',
          status: 'DRAFT'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should support custom pagination', async () => {
      prisma.billing_adjustment.findMany.mockResolvedValue([]);

      await findMany({}, 20, 50);

      expect(prisma.billing_adjustment.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should support custom orderBy', async () => {
      prisma.billing_adjustment.findMany.mockResolvedValue([]);

      await findMany({}, 0, 20, { amount: 'asc' });

      expect(prisma.billing_adjustment.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { amount: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.billing_adjustment.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count all billing adjustments', async () => {
      prisma.billing_adjustment.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.billing_adjustment.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count billing adjustments with filters', async () => {
      prisma.billing_adjustment.count.mockResolvedValue(5);

      const result = await count({ status: 'PAID' });

      expect(result).toBe(5);
      expect(prisma.billing_adjustment.count).toHaveBeenCalledWith({
        where: { deleted_at: null, status: 'PAID' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.billing_adjustment.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a billing adjustment', async () => {
      const billingAdjustmentData = {
        invoice_id: 'invoice-123',
        amount: 100.50,
        status: 'DRAFT',
        reason: 'Discount applied',
        adjusted_at: new Date('2026-01-19')
      };
      const mockCreatedBillingAdjustment = {
        id: 'adjustment-123',
        ...billingAdjustmentData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.billing_adjustment.create.mockResolvedValue(mockCreatedBillingAdjustment);

      const result = await create(billingAdjustmentData);

      expect(result).toEqual(mockCreatedBillingAdjustment);
      expect(prisma.billing_adjustment.create).toHaveBeenCalledWith({
        data: billingAdjustmentData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field_name'] };
      prisma.billing_adjustment.create.mockRejectedValue(error);

      await expect(create({ invoice_id: 'invoice-123' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'invoice_id' };
      prisma.billing_adjustment.create.mockRejectedValue(error);

      await expect(create({ invoice_id: 'invalid-invoice' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.billing_adjustment.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ invoice_id: 'invoice-123' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a billing adjustment', async () => {
      const updateData = {
        amount: 200.75,
        status: 'PAID',
        reason: 'Updated discount'
      };
      const mockUpdatedBillingAdjustment = {
        id: 'adjustment-123',
        invoice_id: 'invoice-123',
        ...updateData,
        adjusted_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-20'),
        deleted_at: null,
        version: 2
      };
      prisma.billing_adjustment.update.mockResolvedValue(mockUpdatedBillingAdjustment);

      const result = await update('adjustment-123', updateData);

      expect(result).toEqual(mockUpdatedBillingAdjustment);
      expect(prisma.billing_adjustment.update).toHaveBeenCalledWith({
        where: { id: 'adjustment-123' },
        data: updateData
      });
    });

    it('should throw HttpError if billing adjustment not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.billing_adjustment.update.mockRejectedValue(error);

      await expect(update('nonexistent-id', { amount: 100 }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field_name'] };
      prisma.billing_adjustment.update.mockRejectedValue(error);

      await expect(update('adjustment-123', { amount: 100 }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'invoice_id' };
      prisma.billing_adjustment.update.mockRejectedValue(error);

      await expect(update('adjustment-123', { invoice_id: 'invalid-invoice' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.billing_adjustment.update.mockRejectedValue(new Error('DB error'));

      await expect(update('adjustment-123', { amount: 100 }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a billing adjustment', async () => {
      const mockDeletedBillingAdjustment = {
        id: 'adjustment-123',
        invoice_id: 'invoice-123',
        amount: 100.50,
        status: 'DRAFT',
        reason: 'Discount applied',
        adjusted_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-20'),
        deleted_at: new Date('2026-01-20'),
        version: 1
      };
      prisma.billing_adjustment.update.mockResolvedValue(mockDeletedBillingAdjustment);

      const result = await softDelete('adjustment-123');

      expect(result).toEqual(mockDeletedBillingAdjustment);
      expect(prisma.billing_adjustment.update).toHaveBeenCalledWith({
        where: { id: 'adjustment-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if billing adjustment not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.billing_adjustment.update.mockRejectedValue(error);

      await expect(softDelete('nonexistent-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.billing_adjustment.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('adjustment-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
