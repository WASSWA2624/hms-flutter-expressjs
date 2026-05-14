/**
 * Appointment participant controller
 *
 * @module modules/appointment-participant/controllers
 * @description Request handlers for appointment participant endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const appointmentParticipantService = require('@services/appointment-participant/appointment-participant.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List appointment participants with pagination
 * GET /api/v1/appointment-participants
 */
const listAppointmentParticipants = asyncHandler(async (req, res) => {
  const {
    appointment_id,
    participant_user_id,
    participant_patient_id,
    role,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    appointment_id,
    participant_user_id,
    participant_patient_id,
    role
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await appointmentParticipantService.listAppointmentParticipants(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.appointment_participant.list.success', result.participants, result.pagination);
});

/**
 * Get appointment participant by ID
 * GET /api/v1/appointment-participants/:id
 */
const getAppointmentParticipantById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const participant = await appointmentParticipantService.getAppointmentParticipantById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment_participant.get.success', participant);
});

/**
 * Create new appointment participant
 * POST /api/v1/appointment-participants
 */
const createAppointmentParticipant = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const participant = await appointmentParticipantService.createAppointmentParticipant(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.appointment_participant.create.success', participant);
});

/**
 * Update appointment participant
 * PUT /api/v1/appointment-participants/:id
 */
const updateAppointmentParticipant = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const participant = await appointmentParticipantService.updateAppointmentParticipant(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment_participant.update.success', participant);
});

/**
 * Delete appointment participant (soft delete)
 * DELETE /api/v1/appointment-participants/:id
 */
const deleteAppointmentParticipant = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await appointmentParticipantService.deleteAppointmentParticipant(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listAppointmentParticipants,
  getAppointmentParticipantById,
  createAppointmentParticipant,
  updateAppointmentParticipant,
  deleteAppointmentParticipant
};
