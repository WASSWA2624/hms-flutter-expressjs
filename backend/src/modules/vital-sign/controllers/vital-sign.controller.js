/**
 * Vital Sign controller
 *
 * @module modules/vital-sign/controllers
 * @description Request handlers for vital sign endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const vitalSignService = require('@services/vital-sign/vital-sign.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List vital signs with pagination
 * GET /api/v1/vital-signs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listVitalSigns = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    vital_type,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    vital_type
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await vitalSignService.listVitalSigns(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.vital_sign.list.success', result.vitalSigns, result.pagination);
});

/**
 * Get vital sign by ID
 * GET /api/v1/vital-signs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getVitalSignById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const vitalSign = await vitalSignService.getVitalSignById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.vital_sign.get.success', vitalSign);
});

/**
 * Create new vital sign
 * POST /api/v1/vital-signs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createVitalSign = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const vitalSign = await vitalSignService.createVitalSign(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.vital_sign.create.success', vitalSign);
});

/**
 * Update vital sign
 * PUT /api/v1/vital-signs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateVitalSign = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const vitalSign = await vitalSignService.updateVitalSign(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.vital_sign.update.success', vitalSign);
});

/**
 * Delete vital sign (soft delete)
 * DELETE /api/v1/vital-signs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteVitalSign = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await vitalSignService.deleteVitalSign(id, req.body, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listVitalSigns,
  getVitalSignById,
  createVitalSign,
  updateVitalSign,
  deleteVitalSign
};
