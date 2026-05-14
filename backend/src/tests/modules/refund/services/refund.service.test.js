/**
 * Refund service tests
 */

const refundService = require('@services/refund/refund.service');
const refundRepository = require('@repositories/refund/refund.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/refund/refund.repository');
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

describe('Refund Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(true);
  });

  describe('listRefunds', () => {
    it('should list refunds with pagination', async () => {
      refundRepository.findMany.mockResolvedValue([{ id: 'refund-1' }]);
      refundRepository.count.mockResolvedValue(1);

      const result = await refundService.listRefunds({}, 1, 20, null, 'asc', userId, ipAddress);

      expect(result.refunds).toEqual([
        expect.objectContaining({ id: 'refund-1' }),
      ]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1
      });
    });

    it('should build query filters', async () => {
      refundRepository.findMany.mockResolvedValue([]);
      refundRepository.count.mockResolvedValue(0);

      await refundService.listRefunds(
        {
          payment_id: 'payment-1',
          refunded_at_from: '2026-01-01T00:00:00.000Z',
          refunded_at_to: '2026-01-10T00:00:00.000Z',
          search: 'duplicate'
        },
        1,
        20,
        'refunded_at',
        'desc'
      );

      expect(refundRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          payment_id: 'payment-1',
          refunded_at: expect.objectContaining({
            gte: expect.any(Date),
            lte: expect.any(Date)
          }),
          OR: expect.any(Array)
        }),
        0,
        20,
        { refunded_at: 'desc' },
        expect.any(Object)
      );
    });
  });

  describe('getRefundById', () => {
    it('should get refund by id', async () => {
      const mockRefund = { id: 'refund-1' };
      refundRepository.findById.mockResolvedValue(mockRefund);

      const result = await refundService.getRefundById('refund-1', userId, ipAddress);
      expect(result).toEqual(expect.objectContaining(mockRefund));
    });

    it('should throw if refund not found', async () => {
      refundRepository.findById.mockResolvedValue(null);
      await expect(refundService.getRefundById('missing', userId, ipAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createRefund', () => {
    it('should create refund and write audit log with tenant_id', async () => {
      const payload = { payment_id: 'payment-1', amount: '10.00' };
      const created = { id: 'refund-1', ...payload };
      refundRepository.create.mockResolvedValue(created);
      refundRepository.findById
        .mockResolvedValueOnce({ id: 'refund-1', payment: { tenant_id: 'tenant-1' } })
        .mockResolvedValueOnce(created);

      const result = await refundService.createRefund(payload, userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(expect.objectContaining(created));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'CREATE',
          entity: 'refund'
        })
      );
    });
  });

  describe('updateRefund', () => {
    it('should update refund and write audit log with resolved tenant_id', async () => {
      const before = { id: 'refund-1', payment: { tenant_id: 'tenant-1' } };
      const after = { id: 'refund-1', reason: 'Updated', payment: { tenant_id: 'tenant-2' } };

      refundRepository.findById
        .mockResolvedValueOnce(before)
        .mockResolvedValueOnce({ id: 'refund-1', payment: { tenant_id: 'tenant-2' } })
        .mockResolvedValueOnce(after);
      refundRepository.update.mockResolvedValue(after);

      const result = await refundService.updateRefund('refund-1', { reason: 'Updated' }, userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(expect.objectContaining(after));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-2',
          action: 'UPDATE',
          entity: 'refund'
        })
      );
    });

    it('should throw if refund missing before update', async () => {
      refundRepository.findById.mockResolvedValue(null);
      await expect(refundService.updateRefund('missing', {}, userId, ipAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('deleteRefund', () => {
    it('should soft delete refund and write audit log', async () => {
      const before = { id: 'refund-1', payment: { tenant_id: 'tenant-1' } };
      refundRepository.findById.mockResolvedValue(before);
      refundRepository.softDelete.mockResolvedValue({ id: 'refund-1', deleted_at: new Date() });

      await refundService.deleteRefund('refund-1', userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(refundRepository.softDelete).toHaveBeenCalledWith('refund-1');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'DELETE',
          entity_id: 'refund-1'
        })
      );
    });
  });
});
