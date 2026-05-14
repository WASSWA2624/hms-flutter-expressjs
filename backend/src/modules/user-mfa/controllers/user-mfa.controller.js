/**
 * User MFA controller
 *
 * @module modules/user-mfa/controllers
 * @description Request handlers for user MFA endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const userMfaService = require('@services/user-mfa/user-mfa.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List user MFAs with pagination
 * GET /api/v1/user-mfas
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listUserMfas = asyncHandler(async (req, res) => {
  const {
    user_id,
    channel,
    is_enabled,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    user_id,
    channel,
    is_enabled
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await userMfaService.listUserMfas(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.user_mfa.list.success', result.user_mfas, result.pagination);
});

/**
 * Get user MFA by ID
 * GET /api/v1/user-mfas/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getUserMfaById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userMfa = await userMfaService.getUserMfaById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_mfa.get.success', userMfa);
});

/**
 * Get user MFAs by user ID
 * GET /api/v1/user-mfas/user/:userId
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getUserMfasByUserId = asyncHandler(async (req, res) => {
  const { userId: targetUserId } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userMfas = await userMfaService.getUserMfasByUserId(targetUserId, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_mfa.list_by_user.success', userMfas);
});

/**
 * Create new user MFA
 * POST /api/v1/user-mfas
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createUserMfa = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userMfa = await userMfaService.createUserMfa(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.user_mfa.create.success', userMfa);
});

/**
 * Update user MFA
 * PUT /api/v1/user-mfas/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateUserMfa = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userMfa = await userMfaService.updateUserMfa(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_mfa.update.success', userMfa);
});

/**
 * Delete user MFA (soft delete)
 * DELETE /api/v1/user-mfas/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteUserMfa = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await userMfaService.deleteUserMfa(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Verify MFA code
 * POST /api/v1/user-mfas/:id/verify
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const verifyMfaCode = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { code } = req.body;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await userMfaService.verifyMfaCode(id, code, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_mfa.verify.success', result);
});

/**
 * Enable MFA
 * POST /api/v1/user-mfas/:id/enable
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const enableMfa = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userMfa = await userMfaService.enableMfa(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_mfa.enable.success', userMfa);
});

/**
 * Disable MFA
 * POST /api/v1/user-mfas/:id/disable
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const disableMfa = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userMfa = await userMfaService.disableMfa(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_mfa.disable.success', userMfa);
});

module.exports = {
  listUserMfas,
  getUserMfaById,
  getUserMfasByUserId,
  createUserMfa,
  updateUserMfa,
  deleteUserMfa,
  verifyMfaCode,
  enableMfa,
  disableMfa
};
