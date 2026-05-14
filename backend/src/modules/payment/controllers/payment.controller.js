/**
 * Payment controller
 *
 * @module modules/payment/controllers
 * @description Request handlers for payment endpoints.
 */

const paymentService = require('@services/payment/payment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List payments with pagination
 * GET /api/v1/payments
 */
const listPayments = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    invoice_id,
    status,
    method,
    paid_at_from,
    paid_at_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    invoice_id,
    status,
    method,
    paid_at_from,
    paid_at_to,
    search
  };

  const result = await paymentService.listPayments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip
  );

  sendPaginated(res, 'messages.payment.list.success', result.payments, result.pagination);
});

/**
 * Get payment by ID
 * GET /api/v1/payments/:id
 */
const getPaymentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const payment = await paymentService.getPaymentById(id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.payment.get.success', payment);
});

/**
 * Create payment
 * POST /api/v1/payments
 */
const createPayment = asyncHandler(async (req, res) => {
  const payment = await paymentService.createPayment(req.body, req.user?.id, req.ip);
  sendSuccess(res, 201, 'messages.payment.create.success', payment);
});

/**
 * Update payment
 * PUT /api/v1/payments/:id
 */
const updatePayment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const payment = await paymentService.updatePayment(id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.payment.update.success', payment);
});

/**
 * Delete payment
 * DELETE /api/v1/payments/:id
 */
const deletePayment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await paymentService.deletePayment(id, req.user?.id, req.ip);
  sendNoContent(res);
});

/**
 * Reconcile payment
 * POST /api/v1/payments/:id/reconcile
 */
const reconcilePayment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const payment = await paymentService.reconcilePayment(id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.payment.reconcile.success', payment);
});

/**
 * Get payment channel breakdown for tenant scope
 * GET /api/v1/payments/:id/channel-breakdown
 */
const getPaymentChannelBreakdown = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const breakdown = await paymentService.getPaymentChannelBreakdown(id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.payment.channel_breakdown.success', breakdown);
});

module.exports = {
  listPayments,
  getPaymentById,
  createPayment,
  updatePayment,
  deletePayment,
  reconcilePayment,
  getPaymentChannelBreakdown
};
