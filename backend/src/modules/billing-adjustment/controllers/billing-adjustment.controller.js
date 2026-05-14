/**
 * Billing Adjustment controller
 *
 * @module modules/billing-adjustment/controllers
 * @description Request handlers for billing adjustment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const billingAdjustmentService = require('@services/billing-adjustment/billing-adjustment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List billing adjustments with pagination
 * GET /api/v1/billing-adjustments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listBillingAdjustments = asyncHandler(async (req, res) => {
  const {
    invoice_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    invoice_id,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await billingAdjustmentService.listBillingAdjustments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.billing_adjustment.list.success', result.billingAdjustments, result.pagination);
});

/**
 * Get billing adjustment by ID
 * GET /api/v1/billing-adjustments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getBillingAdjustmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const billingAdjustment = await billingAdjustmentService.getBillingAdjustmentById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.billing_adjustment.get.success', billingAdjustment);
});

/**
 * Create new billing adjustment
 * POST /api/v1/billing-adjustments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createBillingAdjustment = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const billingAdjustment = await billingAdjustmentService.createBillingAdjustment(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.billing_adjustment.create.success', billingAdjustment);
});

/**
 * Update billing adjustment
 * PUT /api/v1/billing-adjustments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateBillingAdjustment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const billingAdjustment = await billingAdjustmentService.updateBillingAdjustment(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.billing_adjustment.update.success', billingAdjustment);
});

/**
 * Delete billing adjustment (soft delete)
 * DELETE /api/v1/billing-adjustments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteBillingAdjustment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await billingAdjustmentService.deleteBillingAdjustment(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listBillingAdjustments,
  getBillingAdjustmentById,
  createBillingAdjustment,
  updateBillingAdjustment,
  deleteBillingAdjustment
};
