/**
 * Payment Methods controller
 *
 * @module modules/accounts-workspace/controllers
 * @description Request/response layer for Payment Methods. Business rules,
 * scope, and audit live in the service.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const paymentMethodService = require('@services/accounts-workspace/payment-method.service');

const listPaymentMethods = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by: sortBy,
    order,
    ...filters
  } = req.query;

  const result = await paymentMethodService.listPaymentMethods(
    filters,
    Number(page),
    Number(limit),
    req.user,
    sortBy,
    order
  );

  return sendPaginated(
    res,
    'messages.accounts.payment_method.list.success',
    result.items,
    result.pagination
  );
});

const getPaymentMethod = asyncHandler(async (req, res) => {
  const data = await paymentMethodService.getPaymentMethod(
    req.params.paymentMethodIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.payment_method.get.success',
    data
  );
});

const createPaymentMethod = asyncHandler(async (req, res) => {
  const data = await paymentMethodService.createPaymentMethod(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    201,
    'messages.accounts.payment_method.create.success',
    data
  );
});

const updatePaymentMethod = asyncHandler(async (req, res) => {
  const data = await paymentMethodService.updatePaymentMethod(
    req.params.paymentMethodIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.payment_method.update.success',
    data
  );
});

const applyPaymentMethodAction = asyncHandler(async (req, res) => {
  const data = await paymentMethodService.applyPaymentMethodAction(
    req.params.paymentMethodIdentifier,
    req.params.action,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.payment_method.action.success',
    data
  );
});

module.exports = {
  listPaymentMethods,
  getPaymentMethod,
  createPaymentMethod,
  updatePaymentMethod,
  applyPaymentMethodAction,
};
