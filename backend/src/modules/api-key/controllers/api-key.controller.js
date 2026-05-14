/**
 * API Key controller
 *
 * @module modules/api-key/controllers
 * @description Request handlers for API key endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const apiKeyService = require('@services/api-key/api-key.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List API keys with pagination
 * GET /api/v1/api-keys
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listApiKeys = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    user_id,
    is_active,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    user_id,
    is_active,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await apiKeyService.listApiKeys(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.api_key.list.success', result.api_keys, result.pagination);
});

/**
 * Get API key by ID
 * GET /api/v1/api-keys/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getApiKeyById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const apiKey = await apiKeyService.getApiKeyById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.api_key.get.success', apiKey);
});

/**
 * Create new API key
 * POST /api/v1/api-keys
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createApiKey = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const apiKey = await apiKeyService.createApiKey(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.api_key.create.success', apiKey);
});

/**
 * Update API key
 * PUT /api/v1/api-keys/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateApiKey = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const apiKey = await apiKeyService.updateApiKey(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.api_key.update.success', apiKey);
});

/**
 * Delete API key (soft delete)
 * DELETE /api/v1/api-keys/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteApiKey = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await apiKeyService.deleteApiKey(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listApiKeys,
  getApiKeyById,
  createApiKey,
  updateApiKey,
  deleteApiKey
};
