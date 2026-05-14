/**
 * OAuth Account controller
 *
 * @module modules/oauth-account/controllers
 * @description Request handlers for OAuth account endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const oauthAccountService = require('@services/oauth-account/oauth-account.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List OAuth accounts with pagination
 * GET /api/v1/oauth-accounts
 */
const listOAuthAccounts = asyncHandler(async (req, res) => {
  const {
    user_id,
    provider,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = { user_id, provider };
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await oauthAccountService.listOAuthAccounts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.oauth_account.list.success', result.oauth_accounts, result.pagination);
});

/**
 * Get OAuth account by ID
 * GET /api/v1/oauth-accounts/:id
 */
const getOAuthAccountById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const oauthAccount = await oauthAccountService.getOAuthAccountById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.oauth_account.get.success', oauthAccount);
});

/**
 * Get OAuth accounts by user ID
 * GET /api/v1/oauth-accounts/user/:userId
 */
const getOAuthAccountsByUserId = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const requestUserId = req.user?.id;
  const ipAddress = req.ip;

  const oauthAccounts = await oauthAccountService.getOAuthAccountsByUserId(userId, requestUserId, ipAddress);

  sendSuccess(res, 200, 'messages.oauth_account.user_list.success', oauthAccounts);
});

/**
 * Create new OAuth account
 * POST /api/v1/oauth-accounts
 */
const createOAuthAccount = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const oauthAccount = await oauthAccountService.createOAuthAccount(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.oauth_account.create.success', oauthAccount);
});

/**
 * Update OAuth account
 * PUT /api/v1/oauth-accounts/:id
 */
const updateOAuthAccount = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const oauthAccount = await oauthAccountService.updateOAuthAccount(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.oauth_account.update.success', oauthAccount);
});

/**
 * Delete OAuth account (soft delete)
 * DELETE /api/v1/oauth-accounts/:id
 */
const deleteOAuthAccount = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await oauthAccountService.deleteOAuthAccount(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listOAuthAccounts,
  getOAuthAccountById,
  getOAuthAccountsByUserId,
  createOAuthAccount,
  updateOAuthAccount,
  deleteOAuthAccount
};
