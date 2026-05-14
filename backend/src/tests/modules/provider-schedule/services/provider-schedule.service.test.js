/**
 * Provider schedule service tests
 *
 * @module tests/modules/provider-schedule/services
 * @description Tests for provider schedule service business logic
 */

const providerScheduleService = require('@services/provider-schedule/provider-schedule.service');
const providerScheduleRepository = require('@repositories/provider-schedule/provider-schedule.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const prisma = require('@prisma/client');

jest.mock('@repositories/provider-schedule/provider-schedule.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
}));
jest.mock('@prisma/client', () => ({
  user: {
    findFirst: jest.fn(),
  },
  provider_schedule: {
    findMany: jest.fn(),
  },
  availability_slot: {
    findMany: jest.fn(),
  },
  $transaction: jest.fn(),
}));

describe('Provider Schedule Service', () => {
  const tenantId = '550e8400-e29b-41d4-a716-446655440001';
  const facilityId = '550e8400-e29b-41d4-a716-446655440010';
  const providerUserId = '550e8400-e29b-41d4-a716-446655440002';
  const scheduleId = '550e8400-e29b-41d4-a716-446655440000';

  const tx = {
    provider_schedule: {
      create: jest.fn(),
      update: jest.fn(),
      findFirst: jest.fn(),
    },
    availability_slot: {
      createMany: jest.fn(),
      updateMany: jest.fn(),
    },
  };

  const mockProvider = {
    id: providerUserId,
    human_friendly_id: 'USR0000001',
    email: 'doctor@example.com',
    phone: '+256700000001',
    profile: {
      first_name: 'Grace',
      middle_name: 'A',
      last_name: 'Nakalema',
    },
  };

  const buildSchedule = (overrides = {}) => ({
    id: scheduleId,
    tenant_id: tenantId,
    facility_id: facilityId,
    provider_user_id: providerUserId,
    day_of_week: 1,
    schedule_type: 'RECURRING',
    timezone: 'UTC',
    effective_from: new Date('2026-01-01T00:00:00.000Z'),
    effective_to: null,
    start_time: new Date('2026-01-20T08:00:00.000Z'),
    end_time: new Date('2026-01-20T17:00:00.000Z'),
    tenant: {
      id: tenantId,
      human_friendly_id: 'TEN0000001',
      name: 'Tenant A',
    },
    facility: {
      id: facilityId,
      human_friendly_id: 'FAC0000001',
      name: 'Main Facility',
    },
    provider: mockProvider,
    slots: [],
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    prisma.user.findFirst.mockResolvedValue(mockProvider);
    prisma.provider_schedule.findMany.mockResolvedValue([]);
    prisma.availability_slot.findMany.mockResolvedValue([]);
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    tx.provider_schedule.create.mockResolvedValue({ id: scheduleId });
    tx.provider_schedule.update.mockResolvedValue({ id: scheduleId });
    tx.provider_schedule.findFirst.mockResolvedValue(buildSchedule());
    tx.availability_slot.createMany.mockResolvedValue({ count: 0 });
    tx.availability_slot.updateMany.mockResolvedValue({ count: 0 });
  });

  describe('listProviderSchedules', () => {
    it('should list schedules with pagination', async () => {
      providerScheduleRepository.findMany.mockResolvedValue([buildSchedule()]);
      providerScheduleRepository.count.mockResolvedValue(1);

      const result = await providerScheduleService.listProviderSchedules({}, 1, 20, null, 'asc');

      expect(result.schedules).toEqual([
        expect.objectContaining({
          id: scheduleId,
          tenant_id: 'TEN0000001',
          facility_id: 'FAC0000001',
          provider_user_id: 'USR0000001',
          provider_display_name: 'Grace A Nakalema',
        }),
      ]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('should apply filters correctly', async () => {
      providerScheduleRepository.findMany.mockResolvedValue([buildSchedule()]);
      providerScheduleRepository.count.mockResolvedValue(1);

      await providerScheduleService.listProviderSchedules(
        {
          tenant_id: tenantId,
          provider_user_id: providerUserId,
          day_of_week: 1,
        },
        1,
        20,
        null,
        'asc'
      );

      expect(providerScheduleRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          provider_user_id: providerUserId,
          day_of_week: 1,
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });

    it('should throw HttpError on repository error', async () => {
      providerScheduleRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        providerScheduleService.listProviderSchedules({}, 1, 20, null, 'asc')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getProviderScheduleById', () => {
    it('should get schedule by ID', async () => {
      providerScheduleRepository.findById.mockResolvedValue(buildSchedule());

      const result = await providerScheduleService.getProviderScheduleById(scheduleId);

      expect(result).toEqual(
        expect.objectContaining({
          id: scheduleId,
          tenant_id: 'TEN0000001',
          provider_display_name: 'Grace A Nakalema',
        })
      );
      expect(providerScheduleRepository.findById).toHaveBeenCalledWith(
        scheduleId,
        expect.any(Object)
      );
    });

    it('should throw HttpError if schedule not found', async () => {
      providerScheduleRepository.findById.mockResolvedValue(null);

      await expect(providerScheduleService.getProviderScheduleById(scheduleId)).rejects.toMatchObject({
        messageKey: 'errors.provider_schedule.not_found',
        statusCode: 404,
      });
    });
  });

  describe('createProviderSchedule', () => {
    const scheduleData = {
      tenant_id: tenantId,
      facility_id: facilityId,
      provider_user_id: providerUserId,
      day_of_week: 1,
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T17:00:00.000Z',
      effective_from: '2026-01-01T00:00:00.000Z',
    };

    it('should create a schedule', async () => {
      const result = await providerScheduleService.createProviderSchedule(scheduleData, 'user-id', '127.0.0.1');

      expect(result).toEqual(
        expect.objectContaining({
          id: scheduleId,
          tenant_id: 'TEN0000001',
          facility_id: 'FAC0000001',
          provider_user_id: 'USR0000001',
        })
      );
      expect(tx.provider_schedule.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          tenant_id: tenantId,
          facility_id: facilityId,
          provider_user_id: providerUserId,
          day_of_week: 1,
          start_time: new Date('2026-01-20T08:00:00.000Z'),
          end_time: new Date('2026-01-20T17:00:00.000Z'),
        }),
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-id',
          action: 'CREATE',
          entity: 'provider_schedule',
          entity_id: scheduleId,
        })
      );
    });
  });

  describe('updateProviderSchedule', () => {
    it('should update a schedule', async () => {
      const existingSchedule = buildSchedule();
      const updatedSchedule = buildSchedule({ day_of_week: 3 });
      providerScheduleRepository.findById.mockResolvedValue(existingSchedule);
      tx.provider_schedule.findFirst.mockResolvedValue(updatedSchedule);

      const result = await providerScheduleService.updateProviderSchedule(
        scheduleId,
        { day_of_week: 3 },
        'user-id',
        '127.0.0.1'
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: scheduleId,
          day_of_week: 3,
          provider_user_id: 'USR0000001',
        })
      );
      expect(providerScheduleRepository.findById).toHaveBeenCalledWith(
        scheduleId,
        expect.any(Object)
      );
      expect(tx.provider_schedule.update).toHaveBeenCalledWith({
        where: { id: scheduleId },
        data: expect.objectContaining({
          day_of_week: 3,
          start_time: existingSchedule.start_time,
          end_time: existingSchedule.end_time,
        }),
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-id',
          action: 'UPDATE',
          entity: 'provider_schedule',
          entity_id: scheduleId,
          diff: expect.objectContaining({
            before: existingSchedule,
            after: updatedSchedule,
          }),
        })
      );
    });

    it('should throw HttpError if schedule not found', async () => {
      providerScheduleRepository.findById.mockResolvedValue(null);

      await expect(
        providerScheduleService.updateProviderSchedule(scheduleId, { day_of_week: 3 }, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.provider_schedule.not_found',
        statusCode: 404,
      });
    });
  });

  describe('deleteProviderSchedule', () => {
    it('should soft delete a schedule', async () => {
      const existingSchedule = buildSchedule();
      providerScheduleRepository.findById.mockResolvedValue(existingSchedule);

      await providerScheduleService.deleteProviderSchedule(scheduleId, 'user-id', '127.0.0.1');

      expect(providerScheduleRepository.findById).toHaveBeenCalledWith(
        scheduleId,
        expect.any(Object)
      );
      expect(tx.availability_slot.updateMany).toHaveBeenCalled();
      expect(tx.provider_schedule.update).toHaveBeenCalledWith({
        where: { id: scheduleId },
        data: { deleted_at: expect.any(Date) },
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-id',
          action: 'DELETE',
          entity: 'provider_schedule',
          entity_id: scheduleId,
          diff: expect.objectContaining({ before: existingSchedule }),
        })
      );
    });

    it('should throw HttpError if schedule not found', async () => {
      providerScheduleRepository.findById.mockResolvedValue(null);

      await expect(
        providerScheduleService.deleteProviderSchedule(scheduleId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.provider_schedule.not_found',
        statusCode: 404,
      });
    });
  });
});
