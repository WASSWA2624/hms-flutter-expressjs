/**
 * Asset service log controller
 *
 * @module modules/asset-service-log/controllers
 * @description Request handlers for asset service log endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const assetServiceLogService = require('@services/asset-service-log/asset-service-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildRequestContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  ip_address: req.ip,
  user_agent: typeof req.get === 'function' ? req.get('user-agent') : req.headers?.['user-agent']
});

/**
 * List asset service logs with pagination
 * GET /api/v1/asset-service-logs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAssetServiceLogs = asyncHandler(async (req, res) => {
  const {
    asset_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    asset_id,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await assetServiceLogService.listAssetServiceLogs(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress,
    buildRequestContext(req)
  );

  sendPaginated(res, 'messages.asset_service_log.list.success', result.assetServiceLogs, result.pagination);
});

/**
 * Get asset service log by ID
 * GET /api/v1/asset-service-logs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAssetServiceLogById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const assetServiceLog = await assetServiceLogService.getAssetServiceLogById(id, userId, ipAddress, buildRequestContext(req));

  sendSuccess(res, 200, 'messages.asset_service_log.get.success', assetServiceLog);
});

/**
 * Create new asset service log
 * POST /api/v1/asset-service-logs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAssetServiceLog = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const assetServiceLog = await assetServiceLogService.createAssetServiceLog(req.body, userId, ipAddress, buildRequestContext(req));

  sendSuccess(res, 201, 'messages.asset_service_log.create.success', assetServiceLog);
});

/**
 * Update asset service log
 * PUT /api/v1/asset-service-logs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAssetServiceLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const assetServiceLog = await assetServiceLogService.updateAssetServiceLog(id, req.body, userId, ipAddress, buildRequestContext(req));

  sendSuccess(res, 200, 'messages.asset_service_log.update.success', assetServiceLog);
});

/**
 * Delete asset service log (soft delete)
 * DELETE /api/v1/asset-service-logs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAssetServiceLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await assetServiceLogService.deleteAssetServiceLog(id, userId, ipAddress, buildRequestContext(req));

  sendNoContent(res);
});

module.exports = {
  listAssetServiceLogs,
  getAssetServiceLogById,
  createAssetServiceLog,
  updateAssetServiceLog,
  deleteAssetServiceLog
};
