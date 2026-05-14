/**
 * Subscription Invoice repository tests
 *
 * @module tests/modules/subscription-invoice/repositories
 * @description Tests for subscription invoice data access layer
 */

const subscriptionInvoiceRepository = require('../../../../modules/subscription-invoice/repositories/subscription-invoice.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  subscription_invoice: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Subscription Invoice Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find subscription invoice by ID', async () => {
      const mockInvoice = { id: '123', subscription_id: '456', deleted_at: null };
      prisma.subscription_invoice.findFirst.mockResolvedValue(mockInvoice);

      const result = await subscriptionInvoiceRepository.findById('123');

      expect(result).toEqual(mockInvoice);
      expect(prisma.subscription_invoice.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null when not found', async () => {
      prisma.subscription_invoice.findFirst.mockResolvedValue(null);

      const result = await subscriptionInvoiceRepository.findById('999');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription_invoice.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionInvoiceRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple subscription invoices', async () => {
      const mockInvoices = [
        { id: '1', subscription_id: '456', deleted_at: null },
        { id: '2', subscription_id: '456', deleted_at: null }
      ];
      prisma.subscription_invoice.findMany.mockResolvedValue(mockInvoices);

      const result = await subscriptionInvoiceRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockInvoices);
      expect(prisma.subscription_invoice.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { subscription_id: '456' };
      prisma.subscription_invoice.findMany.mockResolvedValue([]);

      await subscriptionInvoiceRepository.findMany(filters, 0, 20);

      expect(prisma.subscription_invoice.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription_invoice.findMany.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionInvoiceRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count subscription invoices', async () => {
      prisma.subscription_invoice.count.mockResolvedValue(5);

      const result = await subscriptionInvoiceRepository.count({});

      expect(result).toBe(5);
      expect(prisma.subscription_invoice.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription_invoice.count.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionInvoiceRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create subscription invoice', async () => {
      const mockData = { subscription_id: '456', invoice_id: '789' };
      const mockCreated = { id: '123', ...mockData };
      prisma.subscription_invoice.create.mockResolvedValue(mockCreated);

      const result = await subscriptionInvoiceRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.subscription_invoice.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['subscription_id', 'invoice_id'] } };
      prisma.subscription_invoice.create.mockRejectedValue(error);

      await expect(subscriptionInvoiceRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'subscription_id' } };
      prisma.subscription_invoice.create.mockRejectedValue(error);

      await expect(subscriptionInvoiceRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update subscription invoice', async () => {
      const mockUpdated = { id: '123', subscription_id: '999' };
      prisma.subscription_invoice.update.mockResolvedValue(mockUpdated);

      const result = await subscriptionInvoiceRepository.update('123', { subscription_id: '999' });

      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError when not found', async () => {
      const error = { code: 'P2025' };
      prisma.subscription_invoice.update.mockRejectedValue(error);

      await expect(subscriptionInvoiceRepository.update('999', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete subscription invoice', async () => {
      const mockDeleted = { id: '123', deleted_at: expect.any(Date) };
      prisma.subscription_invoice.update.mockResolvedValue(mockDeleted);

      const result = await subscriptionInvoiceRepository.softDelete('123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.subscription_invoice.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when not found', async () => {
      const error = { code: 'P2025' };
      prisma.subscription_invoice.update.mockRejectedValue(error);

      await expect(subscriptionInvoiceRepository.softDelete('999')).rejects.toThrow(HttpError);
    });
  });
});
