/**
 * Radiology Result controller
 *
 * @module modules/radiology-result/controllers
 * @description Request handlers for radiology result endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const radiologyResultService = require('@services/radiology-result/radiology-result.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List radiology results with pagination
 * GET /api/v1/radiology-results
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listRadiologyResults = asyncHandler(async (req, res) => {
  const {
    radiology_order_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    radiology_order_id,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await radiologyResultService.listRadiologyResults(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.radiology_result.list.success', result.radiology_results, result.pagination);
});

/**
 * Get radiology result by ID
 * GET /api/v1/radiology-results/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getRadiologyResultById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyResult = await radiologyResultService.getRadiologyResultById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_result.get.success', radiologyResult);
});

/**
 * Create new radiology result
 * POST /api/v1/radiology-results
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createRadiologyResult = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyResult = await radiologyResultService.createRadiologyResult(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.radiology_result.create.success', radiologyResult);
});

/**
 * Update radiology result
 * PUT /api/v1/radiology-results/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateRadiologyResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyResult = await radiologyResultService.updateRadiologyResult(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_result.update.success', radiologyResult);
});

/**
 * Delete radiology result (soft delete)
 * DELETE /api/v1/radiology-results/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteRadiologyResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await radiologyResultService.deleteRadiologyResult(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Sign off radiology result
 * POST /api/v1/radiology-results/:id/sign-off
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const signOffRadiologyResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyResult = await radiologyResultService.signOffRadiologyResult(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_result.sign_off.success', radiologyResult);
});

module.exports = {
  listRadiologyResults,
  getRadiologyResultById,
  createRadiologyResult,
  updateRadiologyResult,
  deleteRadiologyResult,
  signOffRadiologyResult
};
