/**
 * Payment service tests
 */

const paymentService = require('@services/payment/payment.service');
const paymentRepository = require('@repositories/payment/payment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/payment/payment.repository');
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

describe('Payment Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(true);
  });

  describe('listPayments', () => {
    it('should list payments with pagination', async () => {
      paymentRepository.findMany.mockResolvedValue([{ id: 'payment-1' }]);
      paymentRepository.count.mockResolvedValue(1);

      const result = await paymentService.listPayments({}, 1, 20, null, 'asc', userId, ipAddress);

      expect(result.payments).toEqual([
        expect.objectContaining({ id: 'payment-1' }),
      ]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1
      });
    });

    it('should build query filters', async () => {
      paymentRepository.findMany.mockResolvedValue([]);
      paymentRepository.count.mockResolvedValue(0);

      await paymentService.listPayments(
        {
          tenant_id: 'tenant-1',
          status: 'PENDING',
          paid_at_from: '2026-01-01T00:00:00.000Z',
          paid_at_to: '2026-01-10T00:00:00.000Z',
          search: 'TXN'
        },
        1,
        20,
        'created_at',
        'desc'
      );

      expect(paymentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          status: 'PENDING',
          paid_at: expect.objectContaining({
            gte: expect.any(Date),
            lte: expect.any(Date)
          }),
          OR: expect.any(Array)
        }),
        0,
        20,
        { created_at: 'desc' },
        expect.any(Object)
      );
    });
  });

  describe('getPaymentById', () => {
    it('should get payment by id', async () => {
      const mockPayment = { id: 'payment-1' };
      paymentRepository.findById.mockResolvedValue(mockPayment);

      const result = await paymentService.getPaymentById('payment-1', userId, ipAddress);
      expect(result).toEqual(expect.objectContaining(mockPayment));
    });

    it('should throw if payment not found', async () => {
      paymentRepository.findById.mockResolvedValue(null);
      await expect(paymentService.getPaymentById('missing', userId, ipAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createPayment', () => {
    it('should create payment and write audit log with tenant_id', async () => {
      const payload = {
        tenant_id: 'tenant-1',
        invoice_id: 'invoice-1',
        status: 'PENDING',
        method: 'CASH',
        amount: '100.00'
      };
      const created = { id: 'payment-1', ...payload };
      paymentRepository.create.mockResolvedValue(created);
      paymentRepository.findById.mockResolvedValue(created);

      const result = await paymentService.createPayment(payload, userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(expect.objectContaining(created));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'CREATE',
          entity: 'payment',
          entity_id: 'payment-1'
        })
      );
    });
  });

  describe('updatePayment', () => {
    it('should update payment and write audit log with resolved tenant_id', async () => {
      const before = { id: 'payment-1', tenant_id: 'tenant-1', status: 'PENDING' };
      const after = { id: 'payment-1', tenant_id: 'tenant-1', status: 'COMPLETED' };

      paymentRepository.findById
        .mockResolvedValueOnce(before)
        .mockResolvedValueOnce(after);
      paymentRepository.update.mockResolvedValue(after);

      const result = await paymentService.updatePayment('payment-1', { status: 'COMPLETED' }, userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(expect.objectContaining(after));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'UPDATE',
          entity: 'payment'
        })
      );
    });

    it('should throw if payment missing before update', async () => {
      paymentRepository.findById.mockResolvedValue(null);
      await expect(paymentService.updatePayment('missing', {}, userId, ipAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('deletePayment', () => {
    it('should soft delete payment and write audit log', async () => {
      const before = { id: 'payment-1', tenant_id: 'tenant-1' };
      paymentRepository.findById.mockResolvedValue(before);
      paymentRepository.softDelete.mockResolvedValue({ id: 'payment-1', deleted_at: new Date() });

      await paymentService.deletePayment('payment-1', userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(paymentRepository.softDelete).toHaveBeenCalledWith('payment-1');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'DELETE',
          entity_id: 'payment-1'
        })
      );
    });
  });
});
