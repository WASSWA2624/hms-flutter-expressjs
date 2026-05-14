/**
 * Patient Contact controller
 *
 * @module modules/patient-contact/controllers
 * @description Request handlers for patient contact endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const patientContactService = require('@services/patient-contact/patient-contact.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient contacts with pagination
 * GET /api/v1/patient-contacts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPatientContacts = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    patient_id,
    contact_type,
    value,
    is_primary,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    patient_id,
    contact_type,
    value,
    is_primary
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await patientContactService.listPatientContacts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.patient_contact.list.success', result.patientContacts, result.pagination);
});

/**
 * Get patient contact by ID
 * GET /api/v1/patient-contacts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPatientContactById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientContact = await patientContactService.getPatientContactById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.patient_contact.get.success', patientContact);
});

/**
 * Create new patient contact
 * POST /api/v1/patient-contacts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPatientContact = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientContact = await patientContactService.createPatientContact(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.patient_contact.create.success', patientContact);
});

/**
 * Update patient contact
 * PUT /api/v1/patient-contacts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePatientContact = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientContact = await patientContactService.updatePatientContact(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.patient_contact.update.success', patientContact);
});

/**
 * Delete patient contact (soft delete)
 * DELETE /api/v1/patient-contacts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePatientContact = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await patientContactService.deletePatientContact(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPatientContacts,
  getPatientContactById,
  createPatientContact,
  updatePatientContact,
  deletePatientContact
};
