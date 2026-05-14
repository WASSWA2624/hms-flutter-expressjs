/**
 * Admission controller
 *
 * @module modules/admission/controllers
 * @description Request handlers for admission endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const admissionService = require('@services/admission/admission.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List admissions with pagination
 * GET /api/v1/admissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAdmissions = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    encounter_id,
    status,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    encounter_id,
    status
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await admissionService.listAdmissions(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.admission.list.success', result.admissions, result.pagination);
});

/**
 * Get admission by ID
 * GET /api/v1/admissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAdmissionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const admission = await admissionService.getAdmissionById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.admission.get.success', admission);
});

/**
 * Create new admission
 * POST /api/v1/admissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAdmission = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const admission = await admissionService.createAdmission(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.admission.create.success', admission);
});

/**
 * Update admission
 * PUT /api/v1/admissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAdmission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const admission = await admissionService.updateAdmission(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.admission.update.success', admission);
});

/**
 * Delete admission (soft delete)
 * DELETE /api/v1/admissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAdmission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await admissionService.deleteAdmission(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Discharge patient from admission
 * POST /api/v1/admissions/:id/discharge
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const dischargeAdmission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const admission = await admissionService.dischargeAdmission(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.admission.discharge.success', admission);
});

/**
 * Transfer admission
 * POST /api/v1/admissions/:id/transfer
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const transferAdmission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const admission = await admissionService.transferAdmission(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.admission.transfer.success', admission);
});

module.exports = {
  listAdmissions,
  getAdmissionById,
  createAdmission,
  updateAdmission,
  deleteAdmission,
  dischargeAdmission,
  transferAdmission
};
