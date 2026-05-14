/**
 * Imaging asset controller
 *
 * @module modules/imaging-asset/controllers
 * @description Request handlers for imaging asset endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const imagingAssetService = require('@services/imaging-asset/imaging-asset.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List imaging assets with pagination
 * GET /api/v1/imaging-assets
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listImagingAssets = asyncHandler(async (req, res) => {
  const {
    imaging_study_id,
    content_type,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    imaging_study_id,
    content_type
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await imagingAssetService.listImagingAssets(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.imaging_asset.list.success', result.imagingAssets, result.pagination);
});

/**
 * Get imaging asset by ID
 * GET /api/v1/imaging-assets/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getImagingAssetById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const imagingAsset = await imagingAssetService.getImagingAssetById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.imaging_asset.get.success', imagingAsset);
});

/**
 * Create new imaging asset
 * POST /api/v1/imaging-assets
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createImagingAsset = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const imagingAsset = await imagingAssetService.createImagingAsset(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.imaging_asset.create.success', imagingAsset);
});

/**
 * Update imaging asset
 * PUT /api/v1/imaging-assets/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateImagingAsset = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const imagingAsset = await imagingAssetService.updateImagingAsset(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.imaging_asset.update.success', imagingAsset);
});

/**
 * Delete imaging asset (soft delete)
 * DELETE /api/v1/imaging-assets/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteImagingAsset = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await imagingAssetService.deleteImagingAsset(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listImagingAssets,
  getImagingAssetById,
  createImagingAsset,
  updateImagingAsset,
  deleteImagingAsset
};
