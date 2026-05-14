/**
 * Payroll item service tests
 *
 * @module tests/modules/payroll-item/services
 * @description Tests for payroll item service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const payrollItemService = require('@services/payroll-item/payroll-item.service');
const payrollItemRepository = require('@repositories/payroll-item/payroll-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

// Mock dependencies
jest.mock('@repositories/payroll-item/payroll-item.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(),
  resolveIdentifierForPayload: jest.fn(),
  resolveEntityId: jest.fn(),
}));

describe('Payroll Item Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value);
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
    resolveEntityId.mockImplementation(async ({ identifier }) => identifier);
  });

  describe('listPayrollItems', () => {
    it('should list payroll items with pagination', async () => {
      const mockPayrollItems = [{ id: '1', amount: 5000 }];
      payrollItemRepository.findMany.mockResolvedValue(mockPayrollItems);
      payrollItemRepository.count.mockResolvedValue(1);

      const result = await payrollItemService.listPayrollItems({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.payrollItems).toEqual(mockPayrollItems);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.totalPages).toBe(1);
      expect(result.pagination.hasNextPage).toBe(false);
      expect(result.pagination.hasPreviousPage).toBe(false);
      expect(payrollItemRepository.findMany).toHaveBeenCalled();
      expect(payrollItemRepository.count).toHaveBeenCalled();
    });

    it('should handle payroll_run_id filter', async () => {
      payrollItemRepository.findMany.mockResolvedValue([]);
      payrollItemRepository.count.mockResolvedValue(0);

      await payrollItemService.listPayrollItems({ payroll_run_id: '123' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ payroll_run_id: '123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle staff_profile_id filter', async () => {
      payrollItemRepository.findMany.mockResolvedValue([]);
      payrollItemRepository.count.mockResolvedValue(0);

      await payrollItemService.listPayrollItems({ staff_profile_id: 'staff-123' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ staff_profile_id: 'staff-123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle currency filter', async () => {
      payrollItemRepository.findMany.mockResolvedValue([]);
      payrollItemRepository.count.mockResolvedValue(0);

      await payrollItemService.listPayrollItems({ currency: 'USD' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ currency: 'USD' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle amount range filters', async () => {
      payrollItemRepository.findMany.mockResolvedValue([]);
      payrollItemRepository.count.mockResolvedValue(0);

      await payrollItemService.listPayrollItems({ amount_min: 1000, amount_max: 5000 }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(payrollItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ amount: { gte: 1000, lte: 5000 } }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should throw HttpError on repository error', async () => {
      payrollItemRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemService.listPayrollItems({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('getPayrollItemById', () => {
    it('should get payroll item by id', async () => {
      const mockPayrollItem = { id: '123', amount: 5000 };
      payrollItemRepository.findById.mockResolvedValue(mockPayrollItem);

      const result = await payrollItemService.getPayrollItemById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockPayrollItem);
      expect(payrollItemRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if payroll item not found', async () => {
      payrollItemRepository.findById.mockResolvedValue(null);

      await expect(payrollItemService.getPayrollItemById('nonexistent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      payrollItemRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemService.getPayrollItemById('123', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createPayrollItem', () => {
    it('should create payroll item and create audit log', async () => {
      const mockData = { payroll_run_id: '123', staff_profile_id: 'staff-123', amount: 5000, currency: 'USD' };
      const mockPayrollItem = { id: '456', ...mockData };
      payrollItemRepository.create.mockResolvedValue(mockPayrollItem);

      const result = await payrollItemService.createPayrollItem(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockPayrollItem);
      expect(payrollItemRepository.create).toHaveBeenCalledWith(mockData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'payroll_item',
        entity_id: '456'
      }));
    });

    it('should throw HttpError on repository error', async () => {
      payrollItemRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemService.createPayrollItem({}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('updatePayrollItem', () => {
    it('should update payroll item and create audit log', async () => {
      const mockBefore = { id: '123', amount: 5000 };
      const mockAfter = { id: '123', amount: 5500 };
      payrollItemRepository.findById.mockResolvedValue(mockBefore);
      payrollItemRepository.update.mockResolvedValue(mockAfter);

      const result = await payrollItemService.updatePayrollItem('123', { amount: 5500 }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(payrollItemRepository.findById).toHaveBeenCalledWith('123');
      expect(payrollItemRepository.update).toHaveBeenCalledWith('123', { amount: 5500 });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'UPDATE',
        entity: 'payroll_item',
        entity_id: '123'
      }));
    });

    it('should throw HttpError if payroll item not found', async () => {
      payrollItemRepository.findById.mockResolvedValue(null);

      await expect(payrollItemService.updatePayrollItem('nonexistent', {}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      payrollItemRepository.findById.mockResolvedValue({ id: '123' });
      payrollItemRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemService.updatePayrollItem('123', {}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('deletePayrollItem', () => {
    it('should delete payroll item and create audit log', async () => {
      const mockPayrollItem = { id: '123', amount: 5000 };
      payrollItemRepository.findById.mockResolvedValue(mockPayrollItem);
      payrollItemRepository.softDelete.mockResolvedValue(mockPayrollItem);

      await payrollItemService.deletePayrollItem('123', mockUserId, mockIpAddress);

      expect(payrollItemRepository.findById).toHaveBeenCalledWith('123');
      expect(payrollItemRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'payroll_item',
        entity_id: '123'
      }));
    });

    it('should throw HttpError if payroll item not found', async () => {
      payrollItemRepository.findById.mockResolvedValue(null);

      await expect(payrollItemService.deletePayrollItem('nonexistent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      payrollItemRepository.findById.mockResolvedValue({ id: '123' });
      payrollItemRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemService.deletePayrollItem('123', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });
});
