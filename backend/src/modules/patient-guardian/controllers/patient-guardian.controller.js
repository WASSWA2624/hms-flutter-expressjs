/**
 * Patient Guardian controller
 *
 * @module modules/patient-guardian/controllers
 * @description Request handlers for patient guardian endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const patientGuardianService = require('@services/patient-guardian/patient-guardian.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient guardians with pagination
 * GET /api/v1/patient-guardians
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPatientGuardians = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    patient_id,
    name,
    relationship,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    patient_id,
    name,
    relationship,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await patientGuardianService.listPatientGuardians(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.patient_guardian.list.success', result.patientGuardians, result.pagination);
});

/**
 * Get patient guardian by ID
 * GET /api/v1/patient-guardians/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPatientGuardianById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientGuardian = await patientGuardianService.getPatientGuardianById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.patient_guardian.get.success', patientGuardian);
});

/**
 * Create new patient guardian
 * POST /api/v1/patient-guardians
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPatientGuardian = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientGuardian = await patientGuardianService.createPatientGuardian(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.patient_guardian.create.success', patientGuardian);
});

/**
 * Update patient guardian
 * PUT /api/v1/patient-guardians/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePatientGuardian = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patientGuardian = await patientGuardianService.updatePatientGuardian(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.patient_guardian.update.success', patientGuardian);
});

/**
 * Delete patient guardian (soft delete)
 * DELETE /api/v1/patient-guardians/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePatientGuardian = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await patientGuardianService.deletePatientGuardian(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPatientGuardians,
  getPatientGuardianById,
  createPatientGuardian,
  updatePatientGuardian,
  deletePatientGuardian
};
