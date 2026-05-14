/**
 * Appointment reminder controller tests
 *
 * @module tests/modules/appointment-reminder/controllers
 * @description Tests for appointment reminder controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const appointmentReminderController = require('@controllers/appointment-reminder/appointment-reminder.controller');
const appointmentReminderService = require('@services/appointment-reminder/appointment-reminder.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/appointment-reminder/appointment-reminder.service');
jest.mock('@lib/response');

describe('Appointment Reminder Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listAppointmentReminders', () => {
    const mockResult = {
      reminders: [
        { id: '1', appointment_id: '550e8400-e29b-41d4-a716-446655440000', channel: 'EMAIL' },
        { id: '2', appointment_id: '550e8400-e29b-41d4-a716-446655440001', channel: 'SMS' }
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

    it('should list reminders with default pagination', async () => {
      appointmentReminderService.listAppointmentReminders.mockResolvedValue(mockResult);

      await appointmentReminderController.listAppointmentReminders(req, res);

      expect(appointmentReminderService.listAppointmentReminders).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.appointment_reminder.list.success',
        mockResult.reminders,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        appointment_id: '550e8400-e29b-41d4-a716-446655440000',
        channel: 'EMAIL',
        is_sent: 'false',
        due_state: 'DUE',
        page: '2',
        limit: '10'
      };
      appointmentReminderService.listAppointmentReminders.mockResolvedValue(mockResult);

      await appointmentReminderController.listAppointmentReminders(req, res);

      expect(appointmentReminderService.listAppointmentReminders).toHaveBeenCalledWith(
        {
          appointment_id: '550e8400-e29b-41d4-a716-446655440000',
          channel: 'EMAIL',
          is_sent: 'false',
          due_state: 'DUE',
        },
        2,
        10,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getAppointmentReminderById', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockReminder = {
      id: reminderId,
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      channel: 'EMAIL'
    };

    it('should get reminder by ID', async () => {
      req.params = { id: reminderId };
      appointmentReminderService.getAppointmentReminderById.mockResolvedValue(mockReminder);

      await appointmentReminderController.getAppointmentReminderById(req, res);

      expect(appointmentReminderService.getAppointmentReminderById).toHaveBeenCalledWith(
        reminderId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment_reminder.get.success',
        mockReminder
      );
    });
  });

  describe('createAppointmentReminder', () => {
    const createData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440000',
      channel: 'EMAIL',
      scheduled_at: '2026-01-20T08:00:00.000Z'
    };

    const mockCreated = {
      id: '550e8400-e29b-41d4-a716-446655440001',
      ...createData
    };

    it('should create reminder', async () => {
      req.body = createData;
      appointmentReminderService.createAppointmentReminder.mockResolvedValue(mockCreated);

      await appointmentReminderController.createAppointmentReminder(req, res);

      expect(appointmentReminderService.createAppointmentReminder).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.appointment_reminder.create.success',
        mockCreated
      );
    });
  });

  describe('updateAppointmentReminder', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { channel: 'SMS' };
    const mockUpdated = {
      id: reminderId,
      channel: 'SMS'
    };

    it('should update reminder', async () => {
      req.params = { id: reminderId };
      req.body = updateData;
      appointmentReminderService.updateAppointmentReminder.mockResolvedValue(mockUpdated);

      await appointmentReminderController.updateAppointmentReminder(req, res);

      expect(appointmentReminderService.updateAppointmentReminder).toHaveBeenCalledWith(
        reminderId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment_reminder.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteAppointmentReminder', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete reminder', async () => {
      req.params = { id: reminderId };
      appointmentReminderService.deleteAppointmentReminder.mockResolvedValue();

      await appointmentReminderController.deleteAppointmentReminder(req, res);

      expect(appointmentReminderService.deleteAppointmentReminder).toHaveBeenCalledWith(
        reminderId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });

  describe('markAppointmentReminderSent', () => {
    const reminderId = '550e8400-e29b-41d4-a716-446655440000';

    it('should mark reminder as sent', async () => {
      req.params = { id: reminderId };
      req.body = { sent_at: '2026-01-20T08:05:00.000Z' };
      const mockReminder = { id: reminderId, sent_at: new Date('2026-01-20T08:05:00.000Z') };
      appointmentReminderService.markAppointmentReminderSent.mockResolvedValue(mockReminder);

      await appointmentReminderController.markAppointmentReminderSent(req, res);

      expect(appointmentReminderService.markAppointmentReminderSent).toHaveBeenCalledWith(
        reminderId,
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment_reminder.mark_sent.success',
        mockReminder
      );
    });
  });
});
