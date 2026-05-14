/**
 * Dispense Log service tests
 *
 * @module tests/modules/dispense-log/services
 * Per testing.mdc: Mock all external dependencies
 */

// Mock dependencies
jest.mock('@repositories/dispense-log/dispense-log.repository');
jest.mock('@lib/audit');

const dispenseLogRepository = require('@repositories/dispense-log/dispense-log.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listDispenseLogs,
  getDispenseLogById,
  createDispenseLog,
  updateDispenseLog,
  deleteDispenseLog
} = require('@services/dispense-log/dispense-log.service');

describe('Dispense Log Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listDispenseLogs', () => {
    it('should list dispense logs with default pagination', async () => {
      const mockDispenseLogs = [
        { id: 'dispense-1', pharmacy_order_item_id: 'item-123', status: 'PENDING' },
        { id: 'dispense-2', pharmacy_order_item_id: 'item-124', status: 'DISPENSED' }
      ];
      dispenseLogRepository.findMany.mockResolvedValue(mockDispenseLogs);
      dispenseLogRepository.count.mockResolvedValue(10);

      const result = await listDispenseLogs({}, 1, 20);

      expect(result.items).toEqual(mockDispenseLogs);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should filter by pharmacy_order_item_id', async () => {
      const mockDispenseLogs = [{ id: 'dispense-1', pharmacy_order_item_id: 'item-123' }];
      dispenseLogRepository.findMany.mockResolvedValue(mockDispenseLogs);
      dispenseLogRepository.count.mockResolvedValue(1);

      await listDispenseLogs({ pharmacy_order_item_id: 'item-123' }, 1, 20);

      expect(dispenseLogRepository.findMany).toHaveBeenCalledWith(
        { pharmacy_order_item_id: 'item-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by status', async () => {
      const mockDispenseLogs = [{ id: 'dispense-1', status: 'DISPENSED' }];
      dispenseLogRepository.findMany.mockResolvedValue(mockDispenseLogs);
      dispenseLogRepository.count.mockResolvedValue(1);

      await listDispenseLogs({ status: 'DISPENSED' }, 1, 20);

      expect(dispenseLogRepository.findMany).toHaveBeenCalledWith(
        { status: 'DISPENSED' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by date range', async () => {
      const mockDispenseLogs = [{ id: 'dispense-1' }];
      dispenseLogRepository.findMany.mockResolvedValue(mockDispenseLogs);
      dispenseLogRepository.count.mockResolvedValue(1);

      await listDispenseLogs({
        dispensed_at_from: '2026-01-01',
        dispensed_at_to: '2026-12-31'
      }, 1, 20);

      expect(dispenseLogRepository.findMany).toHaveBeenCalledWith(
        {
          dispensed_at: {
            gte: new Date('2026-01-01'),
            lte: new Date('2026-12-31')
          }
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by dispensed_at_from only', async () => {
      const mockDispenseLogs = [];
      dispenseLogRepository.findMany.mockResolvedValue(mockDispenseLogs);
      dispenseLogRepository.count.mockResolvedValue(0);

      await listDispenseLogs({ dispensed_at_from: '2026-01-01' }, 1, 20);

      expect(dispenseLogRepository.findMany).toHaveBeenCalledWith(
        {
          dispensed_at: {
            gte: new Date('2026-01-01')
          }
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      const mockDispenseLogs = [];
      dispenseLogRepository.findMany.mockResolvedValue(mockDispenseLogs);
      dispenseLogRepository.count.mockResolvedValue(45);

      const result = await listDispenseLogs({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getDispenseLogById', () => {
    it('should get dispense log by ID', async () => {
      const mockDispenseLog = { id: 'dispense-123', status: 'PENDING' };
      dispenseLogRepository.findById.mockResolvedValue(mockDispenseLog);

      const result = await getDispenseLogById('dispense-123');

      expect(result).toEqual(mockDispenseLog);
      expect(dispenseLogRepository.findById).toHaveBeenCalledWith('dispense-123');
    });

    it('should return null if dispense log not found', async () => {
      dispenseLogRepository.findById.mockResolvedValue(null);

      const result = await getDispenseLogById('dispense-123');

      expect(result).toBeNull();
    });
  });

  describe('createDispenseLog', () => {
    it('should create dispense log and log audit', async () => {
      const newDispenseLog = {
        pharmacy_order_item_id: 'item-123',
        status: 'PENDING',
        quantity_dispensed: 0
      };
      const mockCreatedDispenseLog = {
        id: 'dispense-123',
        ...newDispenseLog,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19')
      };
      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };

      dispenseLogRepository.create.mockResolvedValue(mockCreatedDispenseLog);
      createAuditLog.mockResolvedValue({});

      const result = await createDispenseLog(newDispenseLog, auditContext);

      expect(result).toEqual(mockCreatedDispenseLog);
      expect(dispenseLogRepository.create).toHaveBeenCalledWith(newDispenseLog);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'dispense_log',
        entity_id: 'dispense-123',
        diff: { after: mockCreatedDispenseLog },
        ip: '127.0.0.1'
      });
    });

    it('should throw error if repository fails', async () => {
      dispenseLogRepository.create.mockRejectedValue(new Error('DB error'));

      await expect(createDispenseLog({}, {}))
        .rejects
        .toThrow('DB error');
    });
  });

  describe('updateDispenseLog', () => {
    it('should update dispense log and log audit', async () => {
      const beforeDispenseLog = {
        id: 'dispense-123',
        status: 'PENDING',
        quantity_dispensed: 0
      };
      const updateData = { status: 'DISPENSED', quantity_dispensed: 10 };
      const afterDispenseLog = {
        id: 'dispense-123',
        status: 'DISPENSED',
        quantity_dispensed: 10
      };
      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };

      dispenseLogRepository.findById.mockResolvedValue(beforeDispenseLog);
      dispenseLogRepository.update.mockResolvedValue(afterDispenseLog);
      createAuditLog.mockResolvedValue({});

      const result = await updateDispenseLog('dispense-123', updateData, auditContext);

      expect(result).toEqual(afterDispenseLog);
      expect(dispenseLogRepository.findById).toHaveBeenCalledWith('dispense-123');
      expect(dispenseLogRepository.update).toHaveBeenCalledWith('dispense-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'dispense_log',
        entity_id: 'dispense-123',
        diff: { before: beforeDispenseLog, after: afterDispenseLog },
        ip: '127.0.0.1'
      });
    });

    it('should throw error if repository fails', async () => {
      dispenseLogRepository.findById.mockResolvedValue({});
      dispenseLogRepository.update.mockRejectedValue(new Error('DB error'));

      await expect(updateDispenseLog('dispense-123', {}, {}))
        .rejects
        .toThrow('DB error');
    });
  });

  describe('deleteDispenseLog', () => {
    it('should soft delete dispense log and log audit', async () => {
      const beforeDispenseLog = {
        id: 'dispense-123',
        status: 'PENDING',
        deleted_at: null
      };
      const afterDispenseLog = {
        id: 'dispense-123',
        status: 'PENDING',
        deleted_at: new Date('2026-01-19')
      };
      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };

      dispenseLogRepository.findById.mockResolvedValue(beforeDispenseLog);
      dispenseLogRepository.softDelete.mockResolvedValue(afterDispenseLog);
      createAuditLog.mockResolvedValue({});

      const result = await deleteDispenseLog('dispense-123', auditContext);

      expect(result).toEqual(afterDispenseLog);
      expect(dispenseLogRepository.findById).toHaveBeenCalledWith('dispense-123');
      expect(dispenseLogRepository.softDelete).toHaveBeenCalledWith('dispense-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'dispense_log',
        entity_id: 'dispense-123',
        diff: { before: beforeDispenseLog, after: afterDispenseLog },
        ip: '127.0.0.1'
      });
    });

    it('should throw error if repository fails', async () => {
      dispenseLogRepository.findById.mockResolvedValue({});
      dispenseLogRepository.softDelete.mockRejectedValue(new Error('DB error'));

      await expect(deleteDispenseLog('dispense-123', {}))
        .rejects
        .toThrow('DB error');
    });
  });
});
