/**
 * Refund controller
 *
 * @module modules/refund/controllers
 * @description Request handlers for refund endpoints.
 */

const refundService = require('@services/refund/refund.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List refunds with pagination
 * GET /api/v1/refunds
 */
const listRefunds = asyncHandler(async (req, res) => {
  const {
    payment_id,
    refunded_at_from,
    refunded_at_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    payment_id,
    refunded_at_from,
    refunded_at_to,
    search
  };

  const result = await refundService.listRefunds(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip
  );

  sendPaginated(res, 'messages.refund.list.success', result.refunds, result.pagination);
});

/**
 * Get refund by ID
 * GET /api/v1/refunds/:id
 */
const getRefundById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const refund = await refundService.getRefundById(id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.refund.get.success', refund);
});

/**
 * Create refund
 * POST /api/v1/refunds
 */
const createRefund = asyncHandler(async (req, res) => {
  const refund = await refundService.createRefund(req.body, req.user?.id, req.ip);
  sendSuccess(res, 201, 'messages.refund.create.success', refund);
});

/**
 * Update refund
 * PUT /api/v1/refunds/:id
 */
const updateRefund = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const refund = await refundService.updateRefund(id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.refund.update.success', refund);
});

/**
 * Delete refund
 * DELETE /api/v1/refunds/:id
 */
const deleteRefund = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await refundService.deleteRefund(id, req.user?.id, req.ip);
  sendNoContent(res);
});

module.exports = {
  listRefunds,
  getRefundById,
  createRefund,
  updateRefund,
  deleteRefund
};

