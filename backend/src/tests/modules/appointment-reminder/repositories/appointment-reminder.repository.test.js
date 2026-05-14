/**
 * Appointment reminder repository tests
 *
 * @module tests/modules/appointment-reminder/repositories
 * @description Tests for appointment reminder repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const appointmentReminderRepository = require('@repositories/appointment-reminder/appointment-reminder.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  appointment_reminder: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Appointment Reminder Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockReminder = {
      id: reminderId,
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      channel: 'EMAIL',
      scheduled_at: new Date('2026-01-20T08:00:00.000Z')
    };

    it('should find reminder by ID', async () => {
      prisma.appointment_reminder.findFirst.mockResolvedValue(mockReminder);

      const result = await appointmentReminderRepository.findById(reminderId);

      expect(result).toEqual(mockReminder);
      expect(prisma.appointment_reminder.findFirst).toHaveBeenCalledWith({
        where: { id: reminderId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if reminder not found', async () => {
      prisma.appointment_reminder.findFirst.mockResolvedValue(null);

      const result = await appointmentReminderRepository.findById(reminderId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted reminders', async () => {
      prisma.appointment_reminder.findFirst.mockResolvedValue(null);

      await appointmentReminderRepository.findById(reminderId);

      expect(prisma.appointment_reminder.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { appointment: true };
      prisma.appointment_reminder.findFirst.mockResolvedValue(mockReminder);

      await appointmentReminderRepository.findById(reminderId, include);

      expect(prisma.appointment_reminder.findFirst).toHaveBeenCalledWith({
        where: { id: reminderId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment_reminder.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentReminderRepository.findById(reminderId)).rejects.toThrow(HttpError);
      await expect(appointmentReminderRepository.findById(reminderId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockReminders = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        appointment_id: '550e8400-e29b-41d4-a716-446655440001',
        channel: 'EMAIL',
        scheduled_at: new Date('2026-01-20T08:00:00.000Z')
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        appointment_id: '550e8400-e29b-41d4-a716-446655440003',
        channel: 'SMS',
        scheduled_at: new Date('2026-01-21T09:00:00.000Z')
      }
    ];

    it('should find many reminders with default params', async () => {
      prisma.appointment_reminder.findMany.mockResolvedValue(mockReminders);

      const result = await appointmentReminderRepository.findMany();

      expect(result).toEqual(mockReminders);
      expect(prisma.appointment_reminder.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { appointment_id: '550e8400-e29b-41d4-a716-446655440001', channel: 'EMAIL' };
      prisma.appointment_reminder.findMany.mockResolvedValue(mockReminders);

      await appointmentReminderRepository.findMany(filters);

      expect(prisma.appointment_reminder.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.appointment_reminder.findMany.mockResolvedValue(mockReminders);

      await appointmentReminderRepository.findMany({}, 20, 10);

      expect(prisma.appointment_reminder.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { scheduled_at: 'asc' };
      prisma.appointment_reminder.findMany.mockResolvedValue(mockReminders);

      await appointmentReminderRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.appointment_reminder.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment_reminder.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentReminderRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count reminders with filters', async () => {
      prisma.appointment_reminder.count.mockResolvedValue(5);

      const filters = { channel: 'EMAIL' };
      const result = await appointmentReminderRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.appointment_reminder.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment_reminder.count.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentReminderRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      channel: 'EMAIL',
      scheduled_at: new Date('2026-01-20T08:00:00.000Z')
    };

    it('should create reminder', async () => {
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...createData };
      prisma.appointment_reminder.create.mockResolvedValue(mockCreated);

      const result = await appointmentReminderRepository.create(createData);

      expect(result).toEqual(mockCreated);
      expect(prisma.appointment_reminder.create).toHaveBeenCalledWith({ data: createData });
    });

    it('should handle foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'appointment_id' }
      };
      prisma.appointment_reminder.create.mockRejectedValue(error);

      await expect(appointmentReminderRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(appointmentReminderRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment_reminder.create.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentReminderRepository.create(createData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { sent_at: new Date('2026-01-20T08:05:00.000Z') };

    it('should update reminder', async () => {
      const mockUpdated = { id: reminderId, ...updateData };
      prisma.appointment_reminder.update.mockResolvedValue(mockUpdated);

      const result = await appointmentReminderRepository.update(reminderId, updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.appointment_reminder.update).toHaveBeenCalledWith({
        where: { id: reminderId },
        data: updateData
      });
    });

    it('should handle reminder not found', async () => {
      const error = { code: 'P2025' };
      prisma.appointment_reminder.update.mockRejectedValue(error);

      await expect(appointmentReminderRepository.update(reminderId, updateData)).rejects.toThrow(HttpError);
      await expect(appointmentReminderRepository.update(reminderId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.appointment_reminder.not_found',
        statusCode: 404
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment_reminder.update.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentReminderRepository.update(reminderId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete reminder', async () => {
      const mockDeleted = { id: reminderId, deleted_at: new Date() };
      prisma.appointment_reminder.update.mockResolvedValue(mockDeleted);

      const result = await appointmentReminderRepository.softDelete(reminderId);

      expect(result).toEqual(mockDeleted);
      expect(prisma.appointment_reminder.update).toHaveBeenCalledWith({
        where: { id: reminderId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should handle reminder not found', async () => {
      const error = { code: 'P2025' };
      prisma.appointment_reminder.update.mockRejectedValue(error);

      await expect(appointmentReminderRepository.softDelete(reminderId)).rejects.toThrow(HttpError);
      await expect(appointmentReminderRepository.softDelete(reminderId)).rejects.toMatchObject({
        messageKey: 'errors.appointment_reminder.not_found',
        statusCode: 404
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment_reminder.update.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentReminderRepository.softDelete(reminderId)).rejects.toThrow(HttpError);
    });
  });
});
