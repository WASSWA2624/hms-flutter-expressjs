/**
 * Diagnosis controller
 *
 * @module modules/diagnosis/controllers
 * @description Request handlers for diagnosis endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const diagnosisService = require('@services/diagnosis/diagnosis.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List diagnoses with pagination
 * GET /api/v1/diagnoses
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listDiagnoses = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    diagnosis_type,
    code,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    diagnosis_type,
    code
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await diagnosisService.listDiagnoses(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.diagnosis.list.success', result.diagnoses, result.pagination);
});

/**
 * Get diagnosis by ID
 * GET /api/v1/diagnoses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getDiagnosisById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const diagnosis = await diagnosisService.getDiagnosisById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.diagnosis.get.success', diagnosis);
});

/**
 * Create new diagnosis
 * POST /api/v1/diagnoses
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createDiagnosis = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const diagnosis = await diagnosisService.createDiagnosis(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.diagnosis.create.success', diagnosis);
});

/**
 * Update diagnosis
 * PUT /api/v1/diagnoses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateDiagnosis = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const diagnosis = await diagnosisService.updateDiagnosis(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.diagnosis.update.success', diagnosis);
});

/**
 * Delete diagnosis (soft delete)
 * DELETE /api/v1/diagnoses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteDiagnosis = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await diagnosisService.deleteDiagnosis(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listDiagnoses,
  getDiagnosisById,
  createDiagnosis,
  updateDiagnosis,
  deleteDiagnosis
};
