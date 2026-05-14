/**
 * Provider schedule repository tests
 *
 * @module tests/modules/provider-schedule/repositories
 * @description Tests for provider schedule repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const providerScheduleRepository = require('@repositories/provider-schedule/provider-schedule.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  provider_schedule: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Provider Schedule Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const scheduleId = '550e8400-e29b-41d4-a716-446655440000';
    const mockSchedule = {
      id: scheduleId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
      day_of_week: 1,
      start_time: new Date('2026-01-20T08:00:00.000Z'),
      end_time: new Date('2026-01-20T17:00:00.000Z')
    };

    it('should find provider schedule by ID', async () => {
      prisma.provider_schedule.findFirst.mockResolvedValue(mockSchedule);

      const result = await providerScheduleRepository.findById(scheduleId);

      expect(result).toEqual(mockSchedule);
      expect(prisma.provider_schedule.findFirst).toHaveBeenCalledWith({
        where: { id: scheduleId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if schedule not found', async () => {
      prisma.provider_schedule.findFirst.mockResolvedValue(null);

      const result = await providerScheduleRepository.findById(scheduleId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted schedules', async () => {
      prisma.provider_schedule.findFirst.mockResolvedValue(null);

      await providerScheduleRepository.findById(scheduleId);

      expect(prisma.provider_schedule.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { provider: true, slots: true };
      prisma.provider_schedule.findFirst.mockResolvedValue(mockSchedule);

      await providerScheduleRepository.findById(scheduleId, include);

      expect(prisma.provider_schedule.findFirst).toHaveBeenCalledWith({
        where: { id: scheduleId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.provider_schedule.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(providerScheduleRepository.findById(scheduleId)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.findById(scheduleId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockSchedules = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
        day_of_week: 1
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440003',
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
        day_of_week: 3
      }
    ];

    it('should find many schedules with default params', async () => {
      prisma.provider_schedule.findMany.mockResolvedValue(mockSchedules);

      const result = await providerScheduleRepository.findMany();

      expect(result).toEqual(mockSchedules);
      expect(prisma.provider_schedule.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440001', day_of_week: 1 };
      prisma.provider_schedule.findMany.mockResolvedValue(mockSchedules);

      await providerScheduleRepository.findMany(filters);

      expect(prisma.provider_schedule.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.provider_schedule.findMany.mockResolvedValue(mockSchedules);

      await providerScheduleRepository.findMany({}, 20, 10);

      expect(prisma.provider_schedule.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { day_of_week: 'asc' };
      prisma.provider_schedule.findMany.mockResolvedValue(mockSchedules);

      await providerScheduleRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.provider_schedule.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should return empty array if no schedules found', async () => {
      prisma.provider_schedule.findMany.mockResolvedValue([]);

      const result = await providerScheduleRepository.findMany();

      expect(result).toEqual([]);
    });

    it('should throw HttpError on database error', async () => {
      prisma.provider_schedule.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(providerScheduleRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count schedules with default filters', async () => {
      prisma.provider_schedule.count.mockResolvedValue(42);

      const result = await providerScheduleRepository.count();

      expect(result).toBe(42);
      expect(prisma.provider_schedule.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count schedules with filters', async () => {
      const filters = { provider_user_id: '550e8400-e29b-41d4-a716-446655440002' };
      prisma.provider_schedule.count.mockResolvedValue(5);

      const result = await providerScheduleRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.provider_schedule.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.provider_schedule.count.mockRejectedValue(new Error('DB Error'));

      await expect(providerScheduleRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const scheduleData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
      day_of_week: 1,
      start_time: new Date('2026-01-20T08:00:00.000Z'),
      end_time: new Date('2026-01-20T17:00:00.000Z')
    };

    const createdSchedule = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...scheduleData
    };

    it('should create a provider schedule', async () => {
      prisma.provider_schedule.create.mockResolvedValue(createdSchedule);

      const result = await providerScheduleRepository.create(scheduleData);

      expect(result).toEqual(createdSchedule);
      expect(prisma.provider_schedule.create).toHaveBeenCalledWith({
        data: scheduleData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['provider_user_id', 'day_of_week'] } };
      prisma.provider_schedule.create.mockRejectedValue(error);

      await expect(providerScheduleRepository.create(scheduleData)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.create(scheduleData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'provider_user_id' } };
      prisma.provider_schedule.create.mockRejectedValue(error);

      await expect(providerScheduleRepository.create(scheduleData)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.create(scheduleData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.provider_schedule.create.mockRejectedValue(new Error('DB Error'));

      await expect(providerScheduleRepository.create(scheduleData)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.create(scheduleData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const scheduleId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { day_of_week: 3 };
    const updatedSchedule = { id: scheduleId, ...updateData };

    it('should update a provider schedule', async () => {
      prisma.provider_schedule.update.mockResolvedValue(updatedSchedule);

      const result = await providerScheduleRepository.update(scheduleId, updateData);

      expect(result).toEqual(updatedSchedule);
      expect(prisma.provider_schedule.update).toHaveBeenCalledWith({
        where: { id: scheduleId },
        data: updateData
      });
    });

    it('should throw HttpError if schedule not found', async () => {
      const error = { code: 'P2025' };
      prisma.provider_schedule.update.mockRejectedValue(error);

      await expect(providerScheduleRepository.update(scheduleId, updateData)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.update(scheduleId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.provider_schedule.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['provider_user_id', 'day_of_week'] } };
      prisma.provider_schedule.update.mockRejectedValue(error);

      await expect(providerScheduleRepository.update(scheduleId, updateData)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.update(scheduleId, updateData)).rejects.toMatchObject({
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'provider_user_id' } };
      prisma.provider_schedule.update.mockRejectedValue(error);

      await expect(providerScheduleRepository.update(scheduleId, updateData)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.update(scheduleId, updateData)).rejects.toMatchObject({
        statusCode: 400
      });
    });
  });

  describe('softDelete', () => {
    const scheduleId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete a provider schedule', async () => {
      const deletedSchedule = { id: scheduleId, deleted_at: expect.any(Date) };
      prisma.provider_schedule.update.mockResolvedValue(deletedSchedule);

      const result = await providerScheduleRepository.softDelete(scheduleId);

      expect(result).toEqual(deletedSchedule);
      expect(prisma.provider_schedule.update).toHaveBeenCalledWith({
        where: { id: scheduleId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if schedule not found', async () => {
      const error = { code: 'P2025' };
      prisma.provider_schedule.update.mockRejectedValue(error);

      await expect(providerScheduleRepository.softDelete(scheduleId)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.softDelete(scheduleId)).rejects.toMatchObject({
        messageKey: 'errors.provider_schedule.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.provider_schedule.update.mockRejectedValue(new Error('DB Error'));

      await expect(providerScheduleRepository.softDelete(scheduleId)).rejects.toThrow(HttpError);
      await expect(providerScheduleRepository.softDelete(scheduleId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
