/**
 * Housekeeping schedule controller tests
 *
 * @module tests/modules/housekeeping-schedule/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies before requiring the controller
jest.mock('@services/housekeeping-schedule/housekeeping-schedule.service');
jest.mock('@lib/response');

const housekeepingScheduleService = require('@services/housekeeping-schedule/housekeeping-schedule.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listHousekeepingSchedules,
  getHousekeepingScheduleById,
  createHousekeepingSchedule,
  updateHousekeepingSchedule,
  deleteHousekeepingSchedule
} = require('@controllers/housekeeping-schedule/housekeeping-schedule.controller');

describe('Housekeeping Schedule Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123', facility_id: 'facility-123' },
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('test-agent')
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe('listHousekeepingSchedules', () => {
    it('should list housekeeping schedules with pagination', async () => {
      const mockResult = {
        housekeepingSchedules: [{ id: 'schedule-1' }, { id: 'schedule-2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };
      housekeepingScheduleService.listHousekeepingSchedules.mockResolvedValue(mockResult);

      mockReq.query = { page: 1, limit: 20 };

      await listHousekeepingSchedules(mockReq, mockRes);

      expect(housekeepingScheduleService.listHousekeepingSchedules).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getHousekeepingScheduleById', () => {
    it('should get housekeeping schedule by ID', async () => {
      const mockSchedule = { id: 'schedule-123', frequency: 'Daily' };
      housekeepingScheduleService.getHousekeepingScheduleById.mockResolvedValue(mockSchedule);

      mockReq.params = { id: 'schedule-123' };

      await getHousekeepingScheduleById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createHousekeepingSchedule', () => {
    it('should create housekeeping schedule', async () => {
      const scheduleData = { frequency: 'Daily' };
      const mockSchedule = { id: 'schedule-123', ...scheduleData };
      housekeepingScheduleService.createHousekeepingSchedule.mockResolvedValue(mockSchedule);

      mockReq.body = scheduleData;

      await createHousekeepingSchedule(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('updateHousekeepingSchedule', () => {
    it('should update housekeeping schedule', async () => {
      const updateData = { frequency: 'Weekly' };
      const mockSchedule = { id: 'schedule-123', ...updateData };
      housekeepingScheduleService.updateHousekeepingSchedule.mockResolvedValue(mockSchedule);

      mockReq.params = { id: 'schedule-123' };
      mockReq.body = updateData;

      await updateHousekeepingSchedule(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteHousekeepingSchedule', () => {
    it('should delete housekeeping schedule', async () => {
      housekeepingScheduleService.deleteHousekeepingSchedule.mockResolvedValue();

      mockReq.params = { id: 'schedule-123' };

      await deleteHousekeepingSchedule(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
