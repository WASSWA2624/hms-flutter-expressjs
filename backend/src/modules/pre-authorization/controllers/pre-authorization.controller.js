/**
 * Pre-authorization controller
 *
 * @module modules/pre-authorization/controllers
 * @description Request handlers for pre-authorization endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const preAuthorizationService = require('@services/pre-authorization/pre-authorization.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List pre-authorizations with pagination
 * GET /api/v1/pre-authorizations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPreAuthorizations = asyncHandler(async (req, res) => {
  const {
    coverage_plan_id,
    status,
    requested_at_from,
    requested_at_to,
    approved_at_from,
    approved_at_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    coverage_plan_id,
    status,
    requested_at_from,
    requested_at_to,
    approved_at_from,
    approved_at_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await preAuthorizationService.listPreAuthorizations(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.pre_authorization.list.success', result.pre_authorizations, result.pagination);
});

/**
 * Get pre-authorization by ID
 * GET /api/v1/pre-authorizations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPreAuthorizationById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const preAuthorization = await preAuthorizationService.getPreAuthorizationById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.pre_authorization.get.success', preAuthorization);
});

/**
 * Create new pre-authorization
 * POST /api/v1/pre-authorizations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPreAuthorization = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const preAuthorization = await preAuthorizationService.createPreAuthorization(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.pre_authorization.create.success', preAuthorization);
});

/**
 * Update pre-authorization
 * PUT /api/v1/pre-authorizations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePreAuthorization = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const preAuthorization = await preAuthorizationService.updatePreAuthorization(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.pre_authorization.update.success', preAuthorization);
});

/**
 * Delete pre-authorization (soft delete)
 * DELETE /api/v1/pre-authorizations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePreAuthorization = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await preAuthorizationService.deletePreAuthorization(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPreAuthorizations,
  getPreAuthorizationById,
  createPreAuthorization,
  updatePreAuthorization,
  deletePreAuthorization
};
