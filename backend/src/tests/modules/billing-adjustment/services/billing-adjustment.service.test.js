/**
 * Billing Adjustment service tests
 *
 * @module tests/modules/billing-adjustment/services
 * @description Tests for billing adjustment service
 * Per testing.mdc: Mock repository, test business logic
 */

const billingAdjustmentService = require('@services/billing-adjustment/billing-adjustment.service');
const billingAdjustmentRepository = require('@repositories/billing-adjustment/billing-adjustment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/billing-adjustment/billing-adjustment.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: (value) => (typeof value === 'string' ? value.trim() : ''),
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      const normalized =
        typeof value === 'string'
          ? value.trim()
          : value == null
            ? ''
            : String(value).trim();
      if (normalized) return normalized;
    }
    return null;
  },
  resolveIdentifierForFilter: async ({ value }) => value,
  resolveIdentifierForPayload: async ({ value, nullable = false }) => {
    if (value === undefined) return undefined;
    if (value === null && nullable) return null;
    return value;
  },
  resolveEntityId: async ({ identifier }) => identifier,
}));

describe('Billing Adjustment Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listBillingAdjustments', () => {
    const mockBillingAdjustments = [
      { id: '1', invoice_id: 'invoice-1', amount: 100.50, status: 'DRAFT', reason: 'Discount' },
      { id: '2', invoice_id: 'invoice-2', amount: 50.25, status: 'PAID', reason: 'Tax adjustment' }
    ];

    it('should list billing adjustments with pagination', async () => {
      billingAdjustmentRepository.findMany.mockResolvedValue(mockBillingAdjustments);
      billingAdjustmentRepository.count.mockResolvedValue(2);

      const result = await billingAdjustmentService.listBillingAdjustments({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('billingAdjustments');
      expect(result.billingAdjustments).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: '1', invoice_id: 'invoice-1' }),
          expect.objectContaining({ id: '2', invoice_id: 'invoice-2' }),
        ])
      );
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply invoice_id filter', async () => {
      const filters = { invoice_id: 'invoice-1' };
      billingAdjustmentRepository.findMany.mockResolvedValue(mockBillingAdjustments);
      billingAdjustmentRepository.count.mockResolvedValue(2);

      await billingAdjustmentService.listBillingAdjustments(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(billingAdjustmentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ invoice_id: 'invoice-1' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should apply status filter', async () => {
      const filters = { status: 'PAID' };
      billingAdjustmentRepository.findMany.mockResolvedValue(mockBillingAdjustments);
      billingAdjustmentRepository.count.mockResolvedValue(2);

      await billingAdjustmentService.listBillingAdjustments(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(billingAdjustmentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'PAID' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should apply search filter', async () => {
      const filters = { search: 'discount' };
      billingAdjustmentRepository.findMany.mockResolvedValue(mockBillingAdjustments);
      billingAdjustmentRepository.count.mockResolvedValue(2);

      await billingAdjustmentService.listBillingAdjustments(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(billingAdjustmentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({ reason: { contains: 'discount' } }),
          ]),
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should handle repository errors', async () => {
      billingAdjustmentRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        billingAdjustmentService.listBillingAdjustments({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getBillingAdjustmentById', () => {
    const billingAdjustmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockBillingAdjustment = { id: billingAdjustmentId, invoice_id: 'invoice-1', amount: 100.50, status: 'DRAFT' };

    it('should get billing adjustment by ID', async () => {
      billingAdjustmentRepository.findById.mockResolvedValue(mockBillingAdjustment);

      const result = await billingAdjustmentService.getBillingAdjustmentById(billingAdjustmentId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(expect.objectContaining(mockBillingAdjustment));
    });

    it('should throw HttpError if billing adjustment not found', async () => {
      billingAdjustmentRepository.findById.mockResolvedValue(null);

      await expect(
        billingAdjustmentService.getBillingAdjustmentById(billingAdjustmentId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.billing_adjustment.not_found',
        statusCode: 404
      });
    });
  });

  describe('createBillingAdjustment', () => {
    const billingAdjustmentData = {
      invoice_id: '550e8400-e29b-41d4-a716-446655440001',
      amount: 100.50,
      status: 'DRAFT',
      reason: 'Discount applied',
      adjusted_at: new Date('2026-01-19')
    };

    const createdBillingAdjustment = { id: '550e8400-e29b-41d4-a716-446655440002', ...billingAdjustmentData };

    it('should create new billing adjustment', async () => {
      billingAdjustmentRepository.create.mockResolvedValue(createdBillingAdjustment);
      createAuditLog.mockResolvedValue(true);

      const result = await billingAdjustmentService.createBillingAdjustment(billingAdjustmentData, 'creator-id', '127.0.0.1');

      expect(result).toEqual(expect.objectContaining(createdBillingAdjustment));
    });

    it('should create audit log for billing adjustment creation', async () => {
      billingAdjustmentRepository.create.mockResolvedValue(createdBillingAdjustment);
      createAuditLog.mockResolvedValue(true);

      await billingAdjustmentService.createBillingAdjustment(billingAdjustmentData, 'creator-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: null,
        user_id: 'creator-id',
        action: 'CREATE',
        entity: 'billing_adjustment',
        entity_id: createdBillingAdjustment.id,
        diff: { after: createdBillingAdjustment },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('updateBillingAdjustment', () => {
    const billingAdjustmentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'PAID', amount: 200.75 };
    const beforeBillingAdjustment = { id: billingAdjustmentId, status: 'DRAFT', amount: 100.50 };
    const afterBillingAdjustment = { id: billingAdjustmentId, status: 'PAID', amount: 200.75 };

    it('should update billing adjustment', async () => {
      billingAdjustmentRepository.findById
        .mockResolvedValueOnce(beforeBillingAdjustment)
        .mockResolvedValueOnce(afterBillingAdjustment);
      billingAdjustmentRepository.update.mockResolvedValue(afterBillingAdjustment);
      createAuditLog.mockResolvedValue(true);

      const result = await billingAdjustmentService.updateBillingAdjustment(billingAdjustmentId, updateData, 'updater-id', '127.0.0.1');

      expect(result).toEqual(expect.objectContaining(afterBillingAdjustment));
    });

    it('should throw HttpError if billing adjustment not found', async () => {
      billingAdjustmentRepository.findById.mockResolvedValue(null);

      await expect(
        billingAdjustmentService.updateBillingAdjustment(billingAdjustmentId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.billing_adjustment.not_found',
        statusCode: 404
      });
    });

    it('should create audit log for billing adjustment update', async () => {
      billingAdjustmentRepository.findById
        .mockResolvedValueOnce(beforeBillingAdjustment)
        .mockResolvedValueOnce(afterBillingAdjustment);
      billingAdjustmentRepository.update.mockResolvedValue(afterBillingAdjustment);
      createAuditLog.mockResolvedValue(true);

      await billingAdjustmentService.updateBillingAdjustment(billingAdjustmentId, updateData, 'updater-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: null,
        user_id: 'updater-id',
        action: 'UPDATE',
        entity: 'billing_adjustment',
        entity_id: afterBillingAdjustment.id,
        diff: { before: beforeBillingAdjustment, after: afterBillingAdjustment },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('deleteBillingAdjustment', () => {
    const billingAdjustmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockBillingAdjustment = { id: billingAdjustmentId, invoice_id: 'invoice-1', amount: 100.50, status: 'DRAFT' };

    it('should delete billing adjustment', async () => {
      billingAdjustmentRepository.findById.mockResolvedValue(mockBillingAdjustment);
      billingAdjustmentRepository.softDelete.mockResolvedValue(undefined);
      createAuditLog.mockResolvedValue(true);

      await billingAdjustmentService.deleteBillingAdjustment(billingAdjustmentId, 'deleter-id', '127.0.0.1');

      expect(billingAdjustmentRepository.softDelete).toHaveBeenCalledWith(billingAdjustmentId);
    });

    it('should throw HttpError if billing adjustment not found', async () => {
      billingAdjustmentRepository.findById.mockResolvedValue(null);

      await expect(
        billingAdjustmentService.deleteBillingAdjustment(billingAdjustmentId, 'deleter-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.billing_adjustment.not_found',
        statusCode: 404
      });
    });

    it('should create audit log for billing adjustment deletion', async () => {
      billingAdjustmentRepository.findById.mockResolvedValue(mockBillingAdjustment);
      billingAdjustmentRepository.softDelete.mockResolvedValue(undefined);
      createAuditLog.mockResolvedValue(true);

      await billingAdjustmentService.deleteBillingAdjustment(billingAdjustmentId, 'deleter-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: null,
        user_id: 'deleter-id',
        action: 'DELETE',
        entity: 'billing_adjustment',
        entity_id: billingAdjustmentId,
        diff: { before: mockBillingAdjustment },
        ip_address: '127.0.0.1'
      });
    });
  });
});
