/**
 * Fiscal Period controller
 *
 * @module modules/accounts-workspace/controllers
 * @description Request/response layer for Fiscal Years & Periods. Business
 * rules, scope, and audit live in the service.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const fiscalPeriodService = require('@services/accounts-workspace/fiscal-period.service');

const listFiscalPeriods = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by: sortBy,
    order,
    ...filters
  } = req.query;

  const result = await fiscalPeriodService.listFiscalPeriods(
    filters,
    Number(page),
    Number(limit),
    req.user,
    sortBy,
    order
  );

  return sendPaginated(
    res,
    'messages.accounts.fiscal_period.list.success',
    result.items,
    result.pagination
  );
});

const getFiscalPeriod = asyncHandler(async (req, res) => {
  const data = await fiscalPeriodService.getFiscalPeriod(
    req.params.fiscalPeriodIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(res, 200, 'messages.accounts.fiscal_period.get.success', data);
});

const createFiscalPeriod = asyncHandler(async (req, res) => {
  const data = await fiscalPeriodService.createFiscalPeriod(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    201,
    'messages.accounts.fiscal_period.create.success',
    data
  );
});

const updateFiscalPeriod = asyncHandler(async (req, res) => {
  const data = await fiscalPeriodService.updateFiscalPeriod(
    req.params.fiscalPeriodIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.fiscal_period.update.success',
    data
  );
});

const applyFiscalPeriodAction = asyncHandler(async (req, res) => {
  const data = await fiscalPeriodService.applyFiscalPeriodAction(
    req.params.fiscalPeriodIdentifier,
    req.params.action,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.fiscal_period.action.success',
    data
  );
});

module.exports = {
  listFiscalPeriods,
  getFiscalPeriod,
  createFiscalPeriod,
  updateFiscalPeriod,
  applyFiscalPeriodAction,
};
