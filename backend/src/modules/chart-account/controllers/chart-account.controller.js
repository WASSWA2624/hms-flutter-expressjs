/**
 * Chart Account controller
 *
 * @module modules/chart-account/controllers
 * @description Request handlers for chart account endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const chartAccountService = require('@services/chart-account/chart-account.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List chart accounts with pagination
 * GET /api/v1/chart-accounts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listChartAccounts = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    account_type,
    parent_id,
    currency,
    is_active,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    account_type,
    parent_id,
    currency,
    is_active,
    search
  };

  const result = await chartAccountService.listChartAccounts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  sendPaginated(
    res,
    'messages.chart_account.list.success',
    result.chartAccounts,
    result.pagination
  );
});

/**
 * Get chart account by ID
 * GET /api/v1/chart-accounts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getChartAccountById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const chartAccount = await chartAccountService.getChartAccountById(id);

  sendSuccess(res, 200, 'messages.chart_account.get.success', chartAccount);
});

/**
 * Create new chart account
 * POST /api/v1/chart-accounts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createChartAccount = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const chartAccount = await chartAccountService.createChartAccount(
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 201, 'messages.chart_account.create.success', chartAccount);
});

/**
 * Update chart account
 * PUT /api/v1/chart-accounts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateChartAccount = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const chartAccount = await chartAccountService.updateChartAccount(
    id,
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.chart_account.update.success', chartAccount);
});

module.exports = {
  listChartAccounts,
  getChartAccountById,
  createChartAccount,
  updateChartAccount
};
