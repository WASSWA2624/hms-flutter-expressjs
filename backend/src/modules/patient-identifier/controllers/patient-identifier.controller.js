/**
 * Patient Identifier controller
 *
 * @module modules/patient-identifier/controllers
 * @description Request handlers for patient identifier endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const patientIdentifierService = require('@services/patient-identifier/patient-identifier.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient identifiers with pagination
 * GET /api/v1/patient-identifiers
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPatientIdentifiers = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    patient_id,
    identifier_type,
    identifier_value,
    is_primary,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    patient_id,
    identifier_type,
    identifier_value,
    is_primary
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await patientIdentifierService.listPatientIdentifiers(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.patient_identifier.list.success', result.patientIdentifiers, result.pagination);
});

/**
 * Get patient identifier by ID
 * GET /api/v1/patient-identifiers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPatientIdentifierById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientIdentifier = await patientIdentifierService.getPatientIdentifierById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.patient_identifier.get.success', patientIdentifier);
});

/**
 * Create new patient identifier
 * POST /api/v1/patient-identifiers
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPatientIdentifier = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientIdentifier = await patientIdentifierService.createPatientIdentifier(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.patient_identifier.create.success', patientIdentifier);
});

/**
 * Update patient identifier
 * PUT /api/v1/patient-identifiers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePatientIdentifier = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientIdentifier = await patientIdentifierService.updatePatientIdentifier(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.patient_identifier.update.success', patientIdentifier);
});

/**
 * Delete patient identifier (soft delete)
 * DELETE /api/v1/patient-identifiers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePatientIdentifier = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await patientIdentifierService.deletePatientIdentifier(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPatientIdentifiers,
  getPatientIdentifierById,
  createPatientIdentifier,
  updatePatientIdentifier,
  deletePatientIdentifier
};
