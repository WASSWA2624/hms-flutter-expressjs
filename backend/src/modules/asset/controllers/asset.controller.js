/**
 * Asset controller
 *
 * @module modules/asset/controllers
 * @description Request handlers for asset endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const assetService = require('@services/asset/asset.service');
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
 * List assets with pagination
 * GET /api/v1/assets
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAssets = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    name,
    asset_tag,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    name,
    asset_tag,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await assetService.listAssets(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress,
    buildRequestContext(req)
  );

  sendPaginated(res, 'messages.asset.list.success', result.assets, result.pagination);
});

/**
 * Get asset by ID
 * GET /api/v1/assets/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAssetById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const asset = await assetService.getAssetById(id, userId, ipAddress, buildRequestContext(req));

  sendSuccess(res, 200, 'messages.asset.get.success', asset);
});

/**
 * Create new asset
 * POST /api/v1/assets
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAsset = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const asset = await assetService.createAsset(req.body, userId, ipAddress, buildRequestContext(req));

  sendSuccess(res, 201, 'messages.asset.create.success', asset);
});

/**
 * Update asset
 * PUT /api/v1/assets/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAsset = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const asset = await assetService.updateAsset(id, req.body, userId, ipAddress, buildRequestContext(req));

  sendSuccess(res, 200, 'messages.asset.update.success', asset);
});

/**
 * Delete asset (soft delete)
 * DELETE /api/v1/assets/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAsset = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await assetService.deleteAsset(id, userId, ipAddress, buildRequestContext(req));

  sendNoContent(res);
});

module.exports = {
  listAssets,
  getAssetById,
  createAsset,
  updateAsset,
  deleteAsset
};
