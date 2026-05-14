/**
 * Dispense Log controller tests
 *
 * @module tests/modules/dispense-log/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/dispense-log/dispense-log.service');
jest.mock('@lib/response');
jest.mock('@lib/errors');

const dispenseLogService = require('@services/dispense-log/dispense-log.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const {
  listDispenseLogs,
  getDispenseLogById,
  createDispenseLog,
  updateDispenseLog,
  deleteDispenseLog
} = require('@controllers/dispense-log/dispense-log.controller');

describe('Dispense Log Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listDispenseLogs', () => {
    it('should list dispense logs with default pagination', async () => {
      const mockResult = {
        items: [
          { id: 'dispense-1', pharmacy_order_item_id: 'item-123', status: 'PENDING' },
          { id: 'dispense-2', pharmacy_order_item_id: 'item-124', status: 'DISPENSED' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      dispenseLogService.listDispenseLogs.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listDispenseLogs(req, res);

      expect(dispenseLogService.listDispenseLogs).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.dispense_log.list.success',
        mockResult.items,
        mockResult.pagination
      );
    });

    it('should list dispense logs with filters', async () => {
      const mockResult = {
        items: [{ id: 'dispense-1', pharmacy_order_item_id: 'item-123', status: 'DISPENSED' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      dispenseLogService.listDispenseLogs.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { pharmacy_order_item_id: 'item-123', status: 'DISPENSED' };

      await listDispenseLogs(req, res);

      expect(dispenseLogService.listDispenseLogs).toHaveBeenCalledWith(
        { pharmacy_order_item_id: 'item-123', status: 'DISPENSED' },
        1,
        20,
        'created_at',
        'desc'
      );
    });

    it('should handle custom sort parameters', async () => {
      const mockResult = { items: [], pagination: {} };
      dispenseLogService.listDispenseLogs.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { sort_by: 'dispensed_at', order: 'asc' };

      await listDispenseLogs(req, res);

      expect(dispenseLogService.listDispenseLogs).toHaveBeenCalledWith(
        {},
        1,
        20,
        'dispensed_at',
        'asc'
      );
    });
  });

  describe('getDispenseLogById', () => {
    it('should get dispense log by ID', async () => {
      const mockDispenseLog = { id: 'dispense-123', status: 'PENDING' };
      dispenseLogService.getDispenseLogById.mockResolvedValue(mockDispenseLog);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params.id = 'dispense-123';

      await getDispenseLogById(req, res);

      expect(dispenseLogService.getDispenseLogById).toHaveBeenCalledWith('dispense-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.dispense_log.get.success',
        mockDispenseLog
      );
    });

    it('should throw HttpError if dispense log not found', async () => {
      dispenseLogService.getDispenseLogById.mockResolvedValue(null);
      HttpError.mockImplementation((message, status) => {
        const error = new Error(message);
        error.status = status;
        return error;
      });

      req.params.id = 'dispense-123';

      await expect(getDispenseLogById(req, res))
        .rejects
        .toThrow();
    });
  });

  describe('createDispenseLog', () => {
    it('should create dispense log', async () => {
      const newDispenseLog = {
        pharmacy_order_item_id: 'item-123',
        status: 'PENDING',
        quantity_dispensed: 0
      };
      const mockCreatedDispenseLog = {
        id: 'dispense-123',
        ...newDispenseLog
      };
      dispenseLogService.createDispenseLog.mockResolvedValue(mockCreatedDispenseLog);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = newDispenseLog;

      await createDispenseLog(req, res);

      expect(dispenseLogService.createDispenseLog).toHaveBeenCalledWith(
        newDispenseLog,
        { user_id: 'user-123', ip: '192.168.1.1' }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.dispense_log.create.success',
        mockCreatedDispenseLog
      );
    });
  });

  describe('updateDispenseLog', () => {
    it('should update dispense log', async () => {
      const updateData = { status: 'DISPENSED', quantity_dispensed: 10 };
      const mockUpdatedDispenseLog = {
        id: 'dispense-123',
        ...updateData
      };
      dispenseLogService.updateDispenseLog.mockResolvedValue(mockUpdatedDispenseLog);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params.id = 'dispense-123';
      req.body = updateData;

      await updateDispenseLog(req, res);

      expect(dispenseLogService.updateDispenseLog).toHaveBeenCalledWith(
        'dispense-123',
        updateData,
        { user_id: 'user-123', ip: '192.168.1.1' }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.dispense_log.update.success',
        mockUpdatedDispenseLog
      );
    });
  });

  describe('deleteDispenseLog', () => {
    it('should delete dispense log', async () => {
      dispenseLogService.deleteDispenseLog.mockResolvedValue({});

      req.params.id = 'dispense-123';

      await deleteDispenseLog(req, res);

      expect(dispenseLogService.deleteDispenseLog).toHaveBeenCalledWith(
        'dispense-123',
        { user_id: 'user-123', ip: '192.168.1.1' }
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
