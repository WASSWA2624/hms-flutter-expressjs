/**
 * API Key Permission controller
 *
 * @module modules/api-key-permission/controllers
 * @description Request handlers for API key permission endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const apiKeyPermissionService = require('@services/api-key-permission/api-key-permission.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List API key permissions with pagination
 * GET /api/v1/api-key-permissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listApiKeyPermissions = asyncHandler(async (req, res) => {
  const {
    api_key_id,
    permission_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    api_key_id,
    permission_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await apiKeyPermissionService.listApiKeyPermissions(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.api_key_permission.list.success', result.api_key_permissions, result.pagination);
});

/**
 * Get API key permission by ID
 * GET /api/v1/api-key-permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getApiKeyPermissionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const apiKeyPermission = await apiKeyPermissionService.getApiKeyPermissionById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.api_key_permission.get.success', apiKeyPermission);
});

/**
 * Create new API key permission
 * POST /api/v1/api-key-permissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createApiKeyPermission = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const apiKeyPermission = await apiKeyPermissionService.createApiKeyPermission(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.api_key_permission.create.success', apiKeyPermission);
});

/**
 * Update API key permission
 * PUT /api/v1/api-key-permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateApiKeyPermission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const apiKeyPermission = await apiKeyPermissionService.updateApiKeyPermission(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.api_key_permission.update.success', apiKeyPermission);
});

/**
 * Delete API key permission (soft delete)
 * DELETE /api/v1/api-key-permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteApiKeyPermission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await apiKeyPermissionService.deleteApiKeyPermission(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listApiKeyPermissions,
  getApiKeyPermissionById,
  createApiKeyPermission,
  updateApiKeyPermission,
  deleteApiKeyPermission
};
