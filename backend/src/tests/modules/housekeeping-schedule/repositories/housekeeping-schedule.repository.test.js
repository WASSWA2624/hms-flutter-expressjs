/**
 * Housekeeping schedule repository tests
 *
 * @module tests/modules/housekeeping-schedule/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  housekeeping_schedule: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/housekeeping-schedule/housekeeping-schedule.repository');

const prisma = require('@prisma/client');

describe('Housekeeping Schedule Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find housekeeping schedule by ID', async () => {
      const mockSchedule = {
        id: 'schedule-123',
        facility_id: 'facility-123',
        room_id: 'room-123',
        frequency: 'Daily',
        start_date: new Date('2026-01-20'),
        end_date: new Date('2026-12-31'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.housekeeping_schedule.findFirst.mockResolvedValue(mockSchedule);

      const result = await findById('schedule-123');

      expect(result).toEqual(mockSchedule);
      expect(prisma.housekeeping_schedule.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'schedule-123',
          deleted_at: null
        }
      });
    });

    it('should return null if housekeeping schedule not found', async () => {
      prisma.housekeeping_schedule.findFirst.mockResolvedValue(null);

      const result = await findById('schedule-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.housekeeping_schedule.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('schedule-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many housekeeping schedules', async () => {
      const mockSchedules = [
        { id: 'schedule-1', frequency: 'Daily' },
        { id: 'schedule-2', frequency: 'Weekly' }
      ];
      prisma.housekeeping_schedule.findMany.mockResolvedValue(mockSchedules);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockSchedules);
    });

    it('should throw HttpError on database error', async () => {
      prisma.housekeeping_schedule.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count housekeeping schedules', async () => {
      prisma.housekeeping_schedule.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
    });

    it('should throw HttpError on database error', async () => {
      prisma.housekeeping_schedule.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new housekeeping schedule', async () => {
      const scheduleData = {
        facility_id: 'facility-123',
        room_id: 'room-123',
        frequency: 'Daily'
      };
      const mockCreatedSchedule = {
        id: 'schedule-new',
        ...scheduleData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.housekeeping_schedule.create.mockResolvedValue(mockCreatedSchedule);

      const result = await create(scheduleData);

      expect(result).toEqual(mockCreatedSchedule);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.housekeeping_schedule.create.mockRejectedValue(error);

      await expect(create({ frequency: 'Daily' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a housekeeping schedule', async () => {
      const updateData = { frequency: 'Weekly' };
      const mockUpdatedSchedule = {
        id: 'schedule-123',
        ...updateData,
        version: 2
      };
      prisma.housekeeping_schedule.update.mockResolvedValue(mockUpdatedSchedule);

      const result = await update('schedule-123', updateData);

      expect(result).toEqual(mockUpdatedSchedule);
    });

    it('should throw HttpError when schedule not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.housekeeping_schedule.update.mockRejectedValue(error);

      await expect(update('schedule-123', { frequency: 'Weekly' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a housekeeping schedule', async () => {
      const mockDeletedSchedule = {
        id: 'schedule-123',
        deleted_at: new Date()
      };
      prisma.housekeeping_schedule.update.mockResolvedValue(mockDeletedSchedule);

      const result = await softDelete('schedule-123');

      expect(result).toEqual(mockDeletedSchedule);
    });

    it('should throw HttpError when schedule not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.housekeeping_schedule.update.mockRejectedValue(error);

      await expect(softDelete('schedule-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
