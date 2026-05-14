/**
 * Payroll run service tests
 *
 * @module tests/modules/payroll-run/services
 * @description Tests for payroll run service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const payrollRunService = require('@services/payroll-run/payroll-run.service');
const payrollRunRepository = require('@repositories/payroll-run/payroll-run.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

// Mock dependencies
jest.mock('@repositories/payroll-run/payroll-run.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(),
  resolveIdentifierForPayload: jest.fn(),
  resolveEntityId: jest.fn(),
}));

describe('Payroll Run Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value);
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
    resolveEntityId.mockImplementation(async ({ identifier }) => identifier);
  });

  describe('listPayrollRuns', () => {
    it('should list payroll runs with pagination', async () => {
      const mockPayrollRuns = [{ id: '1', status: 'DRAFT' }];
      payrollRunRepository.findMany.mockResolvedValue(mockPayrollRuns);
      payrollRunRepository.count.mockResolvedValue(1);

      const result = await payrollRunService.listPayrollRuns({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.payrollRuns).toEqual(mockPayrollRuns);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.totalPages).toBe(1);
      expect(result.pagination.hasNextPage).toBe(false);
      expect(result.pagination.hasPreviousPage).toBe(false);
      expect(payrollRunRepository.findMany).toHaveBeenCalled();
      expect(payrollRunRepository.count).toHaveBeenCalled();
    });

    it('should handle tenant_id filter', async () => {
      payrollRunRepository.findMany.mockResolvedValue([]);
      payrollRunRepository.count.mockResolvedValue(0);

      await payrollRunService.listPayrollRuns({ tenant_id: '123' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollRunRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: '123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle status filter', async () => {
      payrollRunRepository.findMany.mockResolvedValue([]);
      payrollRunRepository.count.mockResolvedValue(0);

      await payrollRunService.listPayrollRuns({ status: 'PROCESSED' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollRunRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'PROCESSED' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle period_start date range filters', async () => {
      const fromDate = new Date('2024-01-01');
      const toDate = new Date('2024-01-31');
      payrollRunRepository.findMany.mockResolvedValue([]);
      payrollRunRepository.count.mockResolvedValue(0);

      await payrollRunService.listPayrollRuns({ period_start_from: fromDate, period_start_to: toDate }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollRunRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ period_start: { gte: fromDate, lte: toDate } }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle period_end date range filters', async () => {
      const fromDate = new Date('2024-01-01');
      const toDate = new Date('2024-01-31');
      payrollRunRepository.findMany.mockResolvedValue([]);
      payrollRunRepository.count.mockResolvedValue(0);

      await payrollRunService.listPayrollRuns({ period_end_from: fromDate, period_end_to: toDate }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollRunRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ period_end: { gte: fromDate, lte: toDate } }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should throw HttpError on repository error', async () => {
      payrollRunRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunService.listPayrollRuns({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('getPayrollRunById', () => {
    it('should get payroll run by id', async () => {
      const mockPayrollRun = { id: '123', status: 'DRAFT' };
      payrollRunRepository.findById.mockResolvedValue(mockPayrollRun);

      const result = await payrollRunService.getPayrollRunById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockPayrollRun);
      expect(payrollRunRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if payroll run not found', async () => {
      payrollRunRepository.findById.mockResolvedValue(null);

      await expect(payrollRunService.getPayrollRunById('nonexistent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      payrollRunRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunService.getPayrollRunById('123', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createPayrollRun', () => {
    it('should create payroll run and create audit log', async () => {
      const mockData = { tenant_id: '123', period_start: new Date(), period_end: new Date(), status: 'DRAFT' };
      const mockPayrollRun = { id: '456', ...mockData };
      payrollRunRepository.create.mockResolvedValue(mockPayrollRun);

      const result = await payrollRunService.createPayrollRun(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockPayrollRun);
      expect(payrollRunRepository.create).toHaveBeenCalledWith(mockData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'payroll_run',
        entity_id: '456'
      }));
    });

    it('should throw HttpError on repository error', async () => {
      payrollRunRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunService.createPayrollRun({}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('updatePayrollRun', () => {
    it('should update payroll run and create audit log', async () => {
      const mockBefore = { id: '123', status: 'DRAFT' };
      const mockAfter = { id: '123', status: 'PROCESSED' };
      payrollRunRepository.findById.mockResolvedValue(mockBefore);
      payrollRunRepository.update.mockResolvedValue(mockAfter);

      const result = await payrollRunService.updatePayrollRun('123', { status: 'PROCESSED' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(payrollRunRepository.findById).toHaveBeenCalledWith('123');
      expect(payrollRunRepository.update).toHaveBeenCalledWith('123', { status: 'PROCESSED' });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'UPDATE',
        entity: 'payroll_run',
        entity_id: '123'
      }));
    });

    it('should throw HttpError if payroll run not found', async () => {
      payrollRunRepository.findById.mockResolvedValue(null);

      await expect(payrollRunService.updatePayrollRun('nonexistent', {}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      payrollRunRepository.findById.mockResolvedValue({ id: '123' });
      payrollRunRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunService.updatePayrollRun('123', {}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('deletePayrollRun', () => {
    it('should delete payroll run and create audit log', async () => {
      const mockPayrollRun = { id: '123', status: 'DRAFT' };
      payrollRunRepository.findById.mockResolvedValue(mockPayrollRun);
      payrollRunRepository.softDelete.mockResolvedValue(mockPayrollRun);

      await payrollRunService.deletePayrollRun('123', mockUserId, mockIpAddress);

      expect(payrollRunRepository.findById).toHaveBeenCalledWith('123');
      expect(payrollRunRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'payroll_run',
        entity_id: '123'
      }));
    });

    it('should throw HttpError if payroll run not found', async () => {
      payrollRunRepository.findById.mockResolvedValue(null);

      await expect(payrollRunService.deletePayrollRun('nonexistent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      payrollRunRepository.findById.mockResolvedValue({ id: '123' });
      payrollRunRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunService.deletePayrollRun('123', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });
});
