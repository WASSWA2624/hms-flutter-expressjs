/**
 * Housekeeping schedule service tests
 *
 * @module tests/modules/housekeeping-schedule/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies before requiring the service
jest.mock('@repositories/housekeeping-schedule/housekeeping-schedule.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null)
}));

const housekeepingScheduleRepository = require('@repositories/housekeeping-schedule/housekeeping-schedule.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listHousekeepingSchedules,
  getHousekeepingScheduleById,
  createHousekeepingSchedule,
  updateHousekeepingSchedule,
  deleteHousekeepingSchedule
} = require('@services/housekeeping-schedule/housekeeping-schedule.service');

describe('Housekeeping Schedule Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listHousekeepingSchedules', () => {
    it('should list housekeeping schedules with pagination', async () => {
      const mockSchedules = [
        { id: 'schedule-1', frequency: 'Daily' },
        { id: 'schedule-2', frequency: 'Weekly' }
      ];
      housekeepingScheduleRepository.findMany.mockResolvedValue(mockSchedules);
      housekeepingScheduleRepository.count.mockResolvedValue(2);

      const result = await listHousekeepingSchedules({}, 1, 20);

      expect(result.housekeepingSchedules).toEqual([
        expect.objectContaining(mockSchedules[0]),
        expect.objectContaining(mockSchedules[1])
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });
  });

  describe('getHousekeepingScheduleById', () => {
    it('should get housekeeping schedule by ID', async () => {
      const mockSchedule = { id: 'schedule-123', frequency: 'Daily' };
      housekeepingScheduleRepository.findById.mockResolvedValue(mockSchedule);

      const result = await getHousekeepingScheduleById('schedule-123');

      expect(result).toEqual(expect.objectContaining(mockSchedule));
    });

    it('should throw error when schedule not found', async () => {
      housekeepingScheduleRepository.findById.mockResolvedValue(null);

      await expect(getHousekeepingScheduleById('schedule-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createHousekeepingSchedule', () => {
    it('should create housekeeping schedule and audit log', async () => {
      const scheduleData = {
        facility_id: 'facility-123',
        frequency: 'Daily'
      };
      const mockSchedule = { id: 'schedule-123', ...scheduleData };
      housekeepingScheduleRepository.create.mockResolvedValue(mockSchedule);
      createAuditLog.mockResolvedValue({});

      const result = await createHousekeepingSchedule(scheduleData, {});

      expect(result).toEqual(expect.objectContaining(mockSchedule));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'HOUSEKEEPING_SCHEDULE_CREATED',
        entity: 'housekeeping_schedule'
      }));
    });
  });

  describe('updateHousekeepingSchedule', () => {
    it('should update housekeeping schedule and create audit log', async () => {
      const beforeSchedule = { id: 'schedule-123', frequency: 'Daily' };
      const afterSchedule = { id: 'schedule-123', frequency: 'Weekly' };
      
      housekeepingScheduleRepository.findById.mockResolvedValue(beforeSchedule);
      housekeepingScheduleRepository.update.mockResolvedValue(afterSchedule);
      createAuditLog.mockResolvedValue({});

      const result = await updateHousekeepingSchedule('schedule-123', { frequency: 'Weekly' }, {});

      expect(result).toEqual(expect.objectContaining(afterSchedule));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'HOUSEKEEPING_SCHEDULE_UPDATED'
      }));
    });
  });

  describe('deleteHousekeepingSchedule', () => {
    it('should delete housekeeping schedule and create audit log', async () => {
      const mockSchedule = { id: 'schedule-123', frequency: 'Daily' };
      housekeepingScheduleRepository.findById.mockResolvedValue(mockSchedule);
      housekeepingScheduleRepository.softDelete.mockResolvedValue(mockSchedule);
      createAuditLog.mockResolvedValue({});

      await deleteHousekeepingSchedule('schedule-123', {});

      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'HOUSEKEEPING_SCHEDULE_DELETED'
      }));
    });
  });
});
