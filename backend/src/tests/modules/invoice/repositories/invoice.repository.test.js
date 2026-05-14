/**
 * Invoice repository tests
 *
 * @module tests/modules/invoice/repositories
 * @description Tests for invoice repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const invoiceRepository = require('@repositories/invoice/invoice.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  invoice: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Invoice Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const invoiceId = '550e8400-e29b-41d4-a716-446655440000';
    const mockInvoice = {
      id: invoiceId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'DRAFT',
      billing_status: 'DRAFT',
      total_amount: '1500.50',
      currency: 'USD'
    };

    it('should find invoice by ID', async () => {
      prisma.invoice.findFirst.mockResolvedValue(mockInvoice);

      const result = await invoiceRepository.findById(invoiceId);

      expect(result).toEqual(mockInvoice);
      expect(prisma.invoice.findFirst).toHaveBeenCalledWith({
        where: { id: invoiceId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if invoice not found', async () => {
      prisma.invoice.findFirst.mockResolvedValue(null);

      const result = await invoiceRepository.findById(invoiceId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted invoices', async () => {
      prisma.invoice.findFirst.mockResolvedValue(null);

      await invoiceRepository.findById(invoiceId);

      expect(prisma.invoice.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { items: true, payments: true };
      prisma.invoice.findFirst.mockResolvedValue(mockInvoice);

      await invoiceRepository.findById(invoiceId, include);

      expect(prisma.invoice.findFirst).toHaveBeenCalledWith({
        where: { id: invoiceId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.invoice.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(invoiceRepository.findById(invoiceId)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.findById(invoiceId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockInvoices = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'DRAFT',
        total_amount: '1000.00'
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'PAID',
        total_amount: '2500.50'
      }
    ];

    it('should find many invoices with default params', async () => {
      prisma.invoice.findMany.mockResolvedValue(mockInvoices);

      const result = await invoiceRepository.findMany();

      expect(result).toEqual(mockInvoices);
      expect(prisma.invoice.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440001', status: 'PAID' };
      prisma.invoice.findMany.mockResolvedValue(mockInvoices);

      await invoiceRepository.findMany(filters);

      expect(prisma.invoice.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.invoice.findMany.mockResolvedValue(mockInvoices);

      await invoiceRepository.findMany({}, 20, 10);

      expect(prisma.invoice.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { issued_at: 'asc' };
      prisma.invoice.findMany.mockResolvedValue(mockInvoices);

      await invoiceRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.invoice.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should apply include parameter', async () => {
      const include = { items: true, payments: true };
      prisma.invoice.findMany.mockResolvedValue(mockInvoices);

      await invoiceRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.invoice.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ include })
      );
    });

    it('should return empty array if no invoices found', async () => {
      prisma.invoice.findMany.mockResolvedValue([]);

      const result = await invoiceRepository.findMany();

      expect(result).toEqual([]);
    });

    it('should throw HttpError on database error', async () => {
      prisma.invoice.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(invoiceRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count invoices with default filters', async () => {
      prisma.invoice.count.mockResolvedValue(42);

      const result = await invoiceRepository.count();

      expect(result).toBe(42);
      expect(prisma.invoice.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count invoices with filters', async () => {
      const filters = { status: 'PAID', tenant_id: '550e8400-e29b-41d4-a716-446655440001' };
      prisma.invoice.count.mockResolvedValue(10);

      const result = await invoiceRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.invoice.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should return 0 if no invoices found', async () => {
      prisma.invoice.count.mockResolvedValue(0);

      const result = await invoiceRepository.count();

      expect(result).toBe(0);
    });

    it('should throw HttpError on database error', async () => {
      prisma.invoice.count.mockRejectedValue(new Error('DB Error'));

      await expect(invoiceRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const invoiceData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'DRAFT',
      billing_status: 'DRAFT',
      total_amount: '1500.50',
      currency: 'USD'
    };

    const createdInvoice = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...invoiceData
    };

    it('should create new invoice', async () => {
      prisma.invoice.create.mockResolvedValue(createdInvoice);

      const result = await invoiceRepository.create(invoiceData);

      expect(result).toEqual(createdInvoice);
      expect(prisma.invoice.create).toHaveBeenCalledWith({
        data: invoiceData
      });
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['id'] }
      };
      prisma.invoice.create.mockRejectedValue(error);

      await expect(invoiceRepository.create(invoiceData)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.create(invoiceData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'tenant_id' }
      };
      prisma.invoice.create.mockRejectedValue(error);

      await expect(invoiceRepository.create(invoiceData)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.create(invoiceData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.invoice.create.mockRejectedValue(new Error('DB Error'));

      await expect(invoiceRepository.create(invoiceData)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.create(invoiceData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const invoiceId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'PAID',
      billing_status: 'PAID'
    };

    const updatedInvoice = {
      id: invoiceId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'PAID',
      billing_status: 'PAID',
      total_amount: '1500.50',
      currency: 'USD'
    };

    it('should update invoice', async () => {
      prisma.invoice.update.mockResolvedValue(updatedInvoice);

      const result = await invoiceRepository.update(invoiceId, updateData);

      expect(result).toEqual(updatedInvoice);
      expect(prisma.invoice.update).toHaveBeenCalledWith({
        where: { id: invoiceId },
        data: updateData
      });
    });

    it('should throw HttpError if invoice not found (P2025)', async () => {
      const error = { code: 'P2025' };
      prisma.invoice.update.mockRejectedValue(error);

      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.invoice.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['id'] }
      };
      prisma.invoice.update.mockRejectedValue(error);

      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'patient_id' }
      };
      prisma.invoice.update.mockRejectedValue(error);

      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.invoice.update.mockRejectedValue(new Error('DB Error'));

      await expect(invoiceRepository.update(invoiceId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const invoiceId = '550e8400-e29b-41d4-a716-446655440000';

    const deletedInvoice = {
      id: invoiceId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      deleted_at: new Date()
    };

    it('should soft delete invoice', async () => {
      prisma.invoice.update.mockResolvedValue(deletedInvoice);

      const result = await invoiceRepository.softDelete(invoiceId);

      expect(result).toEqual(deletedInvoice);
      expect(prisma.invoice.update).toHaveBeenCalledWith({
        where: { id: invoiceId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if invoice not found (P2025)', async () => {
      const error = { code: 'P2025' };
      prisma.invoice.update.mockRejectedValue(error);

      await expect(invoiceRepository.softDelete(invoiceId)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.softDelete(invoiceId)).rejects.toMatchObject({
        messageKey: 'errors.invoice.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.invoice.update.mockRejectedValue(new Error('DB Error'));

      await expect(invoiceRepository.softDelete(invoiceId)).rejects.toThrow(HttpError);
      await expect(invoiceRepository.softDelete(invoiceId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
