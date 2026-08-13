/**
 * Currency rate controller
 *
 * @module modules/accounts-workspace/controllers
 * @description Request/response layer for Currencies & Exchange Rates.
 * Business rules, scope, and audit live in the service.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const currencyRateService = require('@services/accounts-workspace/currency-rate.service');

const listCurrencyRates = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by: sortBy,
    order,
    ...filters
  } = req.query;

  const result = await currencyRateService.listCurrencyRates(
    filters,
    Number(page),
    Number(limit),
    req.user,
    sortBy,
    order
  );

  return sendPaginated(
    res,
    'messages.accounts.currency_rate.list.success',
    result.items,
    result.pagination
  );
});

const getCurrencyRate = asyncHandler(async (req, res) => {
  const data = await currencyRateService.getCurrencyRate(
    req.params.currencyRateIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(res, 200, 'messages.accounts.currency_rate.get.success', data);
});

const createCurrencyRate = asyncHandler(async (req, res) => {
  const data = await currencyRateService.createCurrencyRate(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    201,
    'messages.accounts.currency_rate.create.success',
    data
  );
});

const updateCurrencyRate = asyncHandler(async (req, res) => {
  const data = await currencyRateService.updateCurrencyRate(
    req.params.currencyRateIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.currency_rate.update.success',
    data
  );
});

const applyCurrencyRateAction = asyncHandler(async (req, res) => {
  const data = await currencyRateService.applyCurrencyRateAction(
    req.params.currencyRateIdentifier,
    req.params.action,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.currency_rate.action.success',
    data
  );
});

module.exports = {
  listCurrencyRates,
  getCurrencyRate,
  createCurrencyRate,
  updateCurrencyRate,
  applyCurrencyRateAction,
};
