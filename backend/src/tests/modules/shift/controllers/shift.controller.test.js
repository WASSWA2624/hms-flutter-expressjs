/**
 * Shift controller tests
 *
 * @module tests/modules/shift/controllers
 * @description Tests for shift controller operations
 * Per testing.mdc: Controller tests must mock service layer
 */

const shiftController = require('@controllers/shift/shift.controller');
const shiftService = require('@services/shift/shift.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('@services/shift/shift.service');
jest.mock('@lib/response');

describe('Shift Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe('listShifts', () => {
    it('should list shifts with pagination', async () => {
      const mockResult = {
        shifts: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };
      shiftService.listShifts.mockResolvedValue(mockResult);

      req.query = { page: '1', limit: '20', sort_by: 'created_at', order: 'desc' };

      await shiftController.listShifts(req, res);

      expect(shiftService.listShifts).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.shift.list.success',
        mockResult.shifts,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      const mockResult = {
        shifts: [],
        pagination: { page: 1, limit: 20, total: 0 }
      };
      shiftService.listShifts.mockResolvedValue(mockResult);

      req.query = {
        tenant_id: '123',
        facility_id: '456',
        shift_type: 'DAY',
        status: 'SCHEDULED',
        page: '1',
        limit: '20'
      };

      await shiftController.listShifts(req, res);

      expect(shiftService.listShifts).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          facility_id: '456',
          shift_type: 'DAY',
          status: 'SCHEDULED'
        }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getShiftById', () => {
    it('should get shift by id', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'DAY' };
      shiftService.getShiftById.mockResolvedValue(mockShift);

      req.params = { id: '123' };

      await shiftController.getShiftById(req, res);

      expect(shiftService.getShiftById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.shift.get.success', mockShift);
    });
  });

  describe('createShift', () => {
    it('should create shift', async () => {
      const mockShift = { id: '456', tenant_id: '123', shift_type: 'DAY' };
      shiftService.createShift.mockResolvedValue(mockShift);

      req.body = {
        tenant_id: '123',
        shift_type: 'DAY',
        status: 'SCHEDULED',
        start_time: '2026-01-20T08:00:00.000Z',
        end_time: '2026-01-20T16:00:00.000Z'
      };

      await shiftController.createShift(req, res);

      expect(shiftService.createShift).toHaveBeenCalledWith(req.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.shift.create.success', mockShift);
    });
  });

  describe('updateShift', () => {
    it('should update shift', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'NIGHT' };
      shiftService.updateShift.mockResolvedValue(mockShift);

      req.params = { id: '123' };
      req.body = { shift_type: 'NIGHT' };

      await shiftController.updateShift(req, res);

      expect(shiftService.updateShift).toHaveBeenCalledWith('123', req.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.shift.update.success', mockShift);
    });
  });

  describe('deleteShift', () => {
    it('should delete shift', async () => {
      shiftService.deleteShift.mockResolvedValue();

      req.params = { id: '123' };

      await shiftController.deleteShift(req, res);

      expect(shiftService.deleteShift).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });

  describe('publishShift', () => {
    it('should publish shift with default notify_staff', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'DAY', status: 'SCHEDULED' };
      shiftService.publishShift.mockResolvedValue(mockShift);

      req.params = { id: '123' };
      req.body = {};

      await shiftController.publishShift(req, res);

      expect(shiftService.publishShift).toHaveBeenCalledWith('123', true, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.shift.publish.success', mockShift);
    });

    it('should publish shift with custom notify_staff', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'DAY', status: 'SCHEDULED' };
      shiftService.publishShift.mockResolvedValue(mockShift);

      req.params = { id: '123' };
      req.body = { notify_staff: false };

      await shiftController.publishShift(req, res);

      expect(shiftService.publishShift).toHaveBeenCalledWith('123', false, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.shift.publish.success', mockShift);
    });
  });
});
