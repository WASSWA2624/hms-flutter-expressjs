/**
 * Appointment reminder controller
 */

const appointmentReminderService = require('@services/appointment-reminder/appointment-reminder.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listAppointmentReminders = asyncHandler(async (req, res) => {
  const {
    appointment_id,
    channel,
    is_sent,
    due_state,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    appointment_id,
    channel,
    is_sent,
    due_state,
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await appointmentReminderService.listAppointmentReminders(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.appointment_reminder.list.success', result.reminders, result.pagination);
});

const getAppointmentReminderById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const reminder = await appointmentReminderService.getAppointmentReminderById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment_reminder.get.success', reminder);
});

const createAppointmentReminder = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const reminder = await appointmentReminderService.createAppointmentReminder(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.appointment_reminder.create.success', reminder);
});

const updateAppointmentReminder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const reminder = await appointmentReminderService.updateAppointmentReminder(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment_reminder.update.success', reminder);
});

const deleteAppointmentReminder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await appointmentReminderService.deleteAppointmentReminder(id, userId, ipAddress);

  sendNoContent(res);
});

const markAppointmentReminderSent = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const reminder = await appointmentReminderService.markAppointmentReminderSent(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment_reminder.mark_sent.success', reminder);
});

module.exports = {
  listAppointmentReminders,
  getAppointmentReminderById,
  createAppointmentReminder,
  updateAppointmentReminder,
  deleteAppointmentReminder,
  markAppointmentReminderSent,
};
