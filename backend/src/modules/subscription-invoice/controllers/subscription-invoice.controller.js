/**
 * Subscription Invoice controller
 *
 * @module modules/subscription-invoice/controllers
 * @description Controller layer for subscription invoice endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use response helpers for output.
 */

const subscriptionInvoiceService = require('@services/subscription-invoice/subscription-invoice.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get subscription invoice by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionInvoice = async (req, res) => {
  const { id } = req.params;
  const subscriptionInvoice = await subscriptionInvoiceService.getSubscriptionInvoiceById(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription_invoice.retrieved', subscriptionInvoice);
};

/**
 * List subscription invoices with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listSubscriptionInvoices = async (req, res) => {
  const { page = 1, limit = 20, sort_by = 'created_at', order = 'desc', ...filters } = req.query;

  const result = await subscriptionInvoiceService.listSubscriptionInvoices(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    req.user
  );

  return sendPaginated(
    res,
    'messages.subscription_invoice.list_retrieved',
    result.subscriptionInvoices,
    result.pagination
  );
};

/**
 * Create new subscription invoice
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createSubscriptionInvoice = async (req, res) => {
  const subscriptionInvoice = await subscriptionInvoiceService.createSubscriptionInvoice(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 201, 'messages.subscription_invoice.created', subscriptionInvoice);
};

/**
 * Update subscription invoice
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateSubscriptionInvoice = async (req, res) => {
  const { id } = req.params;
  const subscriptionInvoice = await subscriptionInvoiceService.updateSubscriptionInvoice(
    id,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.subscription_invoice.updated', subscriptionInvoice);
};

/**
 * Delete subscription invoice (soft delete)
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteSubscriptionInvoice = async (req, res) => {
  const { id } = req.params;
  await subscriptionInvoiceService.deleteSubscriptionInvoice(id, req.user, req.ip);
  return res.status(204).send();
};

/**
 * Collect subscription invoice
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const collectSubscriptionInvoice = async (req, res) => {
  const { id } = req.params;
  const result = await subscriptionInvoiceService.collectSubscriptionInvoice(id, req.body, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription_invoice.collect.success', result);
};

/**
 * Retry subscription invoice collection
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const retrySubscriptionInvoice = async (req, res) => {
  const { id } = req.params;
  const result = await subscriptionInvoiceService.retrySubscriptionInvoice(id, req.body, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription_invoice.retry.success', result);
};

module.exports = {
  getSubscriptionInvoice,
  listSubscriptionInvoices,
  createSubscriptionInvoice,
  updateSubscriptionInvoice,
  deleteSubscriptionInvoice,
  collectSubscriptionInvoice,
  retrySubscriptionInvoice
};
