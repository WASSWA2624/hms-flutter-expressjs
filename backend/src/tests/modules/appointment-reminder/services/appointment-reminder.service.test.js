/**
 * Appointment reminder service tests
 *
 * @module tests/modules/appointment-reminder/services
 * @description Tests for appointment reminder business logic
 */

const appointmentReminderService = require('@services/appointment-reminder/appointment-reminder.service');
const appointmentReminderRepository = require('@repositories/appointment-reminder/appointment-reminder.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

jest.mock('@repositories/appointment-reminder/appointment-reminder.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Appointment Reminder Service', () => {
  const reminderId = '550e8400-e29b-41d4-a716-446655440000';
  const appointmentId = '550e8400-e29b-41d4-a716-446655440001';
  const userId = 'user-id';
  const ipAddress = '127.0.0.1';

  const mockReminder = {
    id: reminderId,
    appointment_id: appointmentId,
    channel: 'EMAIL',
    scheduled_at: new Date('2026-01-20T08:00:00.000Z'),
    sent_at: null,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier }) =>
      identifier ? { id: identifier } : null
    );
  });

  describe('listAppointmentReminders', () => {
    const mockReminders = [
      mockReminder,
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        appointment_id: '550e8400-e29b-41d4-a716-446655440003',
        channel: 'SMS',
        scheduled_at: new Date('2026-01-21T09:00:00.000Z'),
        sent_at: new Date('2026-01-21T09:05:00.000Z'),
      },
    ];

    it('should list reminders with pagination', async () => {
      appointmentReminderRepository.findMany.mockResolvedValue(mockReminders);
      appointmentReminderRepository.count.mockResolvedValue(2);

      const result = await appointmentReminderService.listAppointmentReminders(
        {},
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(result).toHaveProperty('reminders', mockReminders);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('should apply filters correctly', async () => {
      appointmentReminderRepository.findMany.mockResolvedValue(mockReminders);
      appointmentReminderRepository.count.mockResolvedValue(2);

      await appointmentReminderService.listAppointmentReminders(
        { appointment_id: appointmentId, channel: 'EMAIL' },
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(appointmentReminderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          appointment_id: appointmentId,
          channel: 'EMAIL',
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      appointmentReminderRepository.findMany.mockResolvedValue(mockReminders);
      appointmentReminderRepository.count.mockResolvedValue(42);

      const result = await appointmentReminderService.listAppointmentReminders(
        {},
        2,
        10,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true,
      });
    });

    it('should handle repository errors', async () => {
      appointmentReminderRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentReminderService.listAppointmentReminders({}, 1, 20, null, 'asc', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should apply is_sent filter', async () => {
      appointmentReminderRepository.findMany.mockResolvedValue(mockReminders);
      appointmentReminderRepository.count.mockResolvedValue(2);

      await appointmentReminderService.listAppointmentReminders(
        { is_sent: true },
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(appointmentReminderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          AND: expect.arrayContaining([{ sent_at: { not: null } }]),
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });

    it('should apply due_state overdue filter', async () => {
      appointmentReminderRepository.findMany.mockResolvedValue(mockReminders);
      appointmentReminderRepository.count.mockResolvedValue(2);

      await appointmentReminderService.listAppointmentReminders(
        { due_state: 'OVERDUE' },
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(appointmentReminderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          AND: expect.arrayContaining([
            { sent_at: null },
            expect.objectContaining({ scheduled_at: expect.any(Object) }),
          ]),
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });
  });

  describe('getAppointmentReminderById', () => {
    it('should get reminder by ID', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: reminderId });
      appointmentReminderRepository.findById.mockResolvedValue(mockReminder);

      const result = await appointmentReminderService.getAppointmentReminderById(
        reminderId,
        userId,
        ipAddress
      );

      expect(result).toEqual(mockReminder);
      expect(appointmentReminderRepository.findById).toHaveBeenCalledWith(
        reminderId,
        expect.any(Object)
      );
    });

    it('should throw error if reminder not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        appointmentReminderService.getAppointmentReminderById(reminderId, userId, ipAddress)
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment_reminder.not_found',
        statusCode: 404,
      });
    });
  });

  describe('createAppointmentReminder', () => {
    it('should create reminder', async () => {
      appointmentReminderRepository.create.mockResolvedValue(mockReminder);
      appointmentReminderRepository.findById.mockResolvedValue(mockReminder);

      const result = await appointmentReminderService.createAppointmentReminder(
        {
          appointment_id: appointmentId,
          channel: 'EMAIL',
          scheduled_at: new Date('2026-01-20T08:00:00.000Z'),
        },
        userId,
        ipAddress
      );

      expect(result).toEqual(mockReminder);
      expect(appointmentReminderRepository.create).toHaveBeenCalledWith({
        appointment_id: appointmentId,
        channel: 'EMAIL',
        scheduled_at: new Date('2026-01-20T08:00:00.000Z'),
      });
      expect(appointmentReminderRepository.findById).toHaveBeenCalledWith(
        reminderId,
        expect.any(Object)
      );
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'CREATE',
        entity: 'appointment_reminder',
        entity_id: reminderId,
        diff: { after: mockReminder },
        ip_address: ipAddress,
      });
    });

    it('should not throw if audit log fails', async () => {
      appointmentReminderRepository.create.mockResolvedValue(mockReminder);
      appointmentReminderRepository.findById.mockResolvedValue(mockReminder);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit Error')));

      const result = await appointmentReminderService.createAppointmentReminder(
        {
          appointment_id: appointmentId,
          channel: 'EMAIL',
          scheduled_at: new Date('2026-01-20T08:00:00.000Z'),
        },
        userId,
        ipAddress
      );

      expect(result).toEqual(mockReminder);
    });
  });

  describe('updateAppointmentReminder', () => {
    it('should update reminder', async () => {
      const updatedReminder = {
        ...mockReminder,
        sent_at: new Date('2026-01-20T08:05:00.000Z'),
      };

      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: reminderId });
      appointmentReminderRepository.findById
        .mockResolvedValueOnce(mockReminder)
        .mockResolvedValueOnce(updatedReminder);
      appointmentReminderRepository.update.mockResolvedValue(updatedReminder);

      const result = await appointmentReminderService.updateAppointmentReminder(
        reminderId,
        { sent_at: new Date('2026-01-20T08:05:00.000Z') },
        userId,
        ipAddress
      );

      expect(result).toEqual(updatedReminder);
      expect(appointmentReminderRepository.findById).toHaveBeenNthCalledWith(
        1,
        reminderId,
        expect.any(Object)
      );
      expect(appointmentReminderRepository.update).toHaveBeenCalledWith(reminderId, {
        sent_at: new Date('2026-01-20T08:05:00.000Z'),
      });
      expect(appointmentReminderRepository.findById).toHaveBeenNthCalledWith(
        2,
        reminderId,
        expect.any(Object)
      );
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'UPDATE',
        entity: 'appointment_reminder',
        entity_id: reminderId,
        diff: { before: mockReminder, after: updatedReminder },
        ip_address: ipAddress,
      });
    });

    it('should throw error if reminder not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        appointmentReminderService.updateAppointmentReminder(
          reminderId,
          { sent_at: new Date('2026-01-20T08:05:00.000Z') },
          userId,
          ipAddress
        )
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAppointmentReminder', () => {
    it('should soft delete reminder', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: reminderId });
      appointmentReminderRepository.findById.mockResolvedValue(mockReminder);
      appointmentReminderRepository.softDelete.mockResolvedValue({});

      await appointmentReminderService.deleteAppointmentReminder(reminderId, userId, ipAddress);

      expect(appointmentReminderRepository.findById).toHaveBeenCalledWith(
        reminderId,
        expect.any(Object)
      );
      expect(appointmentReminderRepository.softDelete).toHaveBeenCalledWith(reminderId);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'DELETE',
        entity: 'appointment_reminder',
        entity_id: reminderId,
        diff: { before: mockReminder },
        ip_address: ipAddress,
      });
    });

    it('should throw error if reminder not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        appointmentReminderService.deleteAppointmentReminder(reminderId, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('markAppointmentReminderSent', () => {
    it('should mark reminder as sent when currently unsent', async () => {
      const sentReminder = {
        ...mockReminder,
        sent_at: new Date('2026-01-20T08:05:00.000Z'),
      };

      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: reminderId });
      appointmentReminderRepository.findById
        .mockResolvedValueOnce(mockReminder)
        .mockResolvedValueOnce(sentReminder);
      appointmentReminderRepository.update.mockResolvedValue(sentReminder);

      const result = await appointmentReminderService.markAppointmentReminderSent(
        reminderId,
        { sent_at: '2026-01-20T08:05:00.000Z' },
        userId,
        ipAddress
      );

      expect(result).toEqual(sentReminder);
      expect(appointmentReminderRepository.update).toHaveBeenCalledWith(
        reminderId,
        expect.objectContaining({ sent_at: expect.any(Date) })
      );
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'MARK_SENT',
        entity: 'appointment_reminder',
        entity_id: reminderId,
        diff: { before: mockReminder, after: sentReminder },
        ip_address: ipAddress,
      });
    });

    it('should be idempotent when reminder is already sent', async () => {
      const alreadySent = {
        ...mockReminder,
        sent_at: new Date('2026-01-20T08:00:00.000Z'),
      };

      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: reminderId });
      appointmentReminderRepository.findById.mockResolvedValueOnce(alreadySent);

      const result = await appointmentReminderService.markAppointmentReminderSent(
        reminderId,
        {},
        userId,
        ipAddress
      );

      expect(result).toEqual(alreadySent);
      expect(appointmentReminderRepository.update).not.toHaveBeenCalled();
      expect(createAuditLog).not.toHaveBeenCalled();
    });
  });
});
