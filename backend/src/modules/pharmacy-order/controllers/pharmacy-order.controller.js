/**
 * Pharmacy order controller
 *
 * @module modules/pharmacy-order/controllers
 * @description Request handlers for pharmacy order endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const pharmacyOrderService = require('@services/pharmacy-order/pharmacy-order.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List pharmacy orders with pagination
 * GET /api/v1/pharmacy-orders
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPharmacyOrders = asyncHandler(async (req, res) => {
  const {
    patient_id,
    encounter_id,
    status,
    ordered_at_from,
    ordered_at_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    patient_id,
    encounter_id,
    status,
    ordered_at_from,
    ordered_at_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await pharmacyOrderService.listPharmacyOrders(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress,
    req.user || {}
  );

  sendPaginated(res, 'messages.pharmacy_order.list.success', result.pharmacyOrders, result.pagination);
});

/**
 * Get pharmacy order by ID
 * GET /api/v1/pharmacy-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPharmacyOrderById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pharmacyOrder = await pharmacyOrderService.getPharmacyOrderById(
    id,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.pharmacy_order.get.success', pharmacyOrder);
});

/**
 * Create new pharmacy order
 * POST /api/v1/pharmacy-orders
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPharmacyOrder = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pharmacyOrder = await pharmacyOrderService.createPharmacyOrder(
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 201, 'messages.pharmacy_order.create.success', pharmacyOrder);
});

/**
 * Update pharmacy order
 * PUT /api/v1/pharmacy-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePharmacyOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pharmacyOrder = await pharmacyOrderService.updatePharmacyOrder(
    id,
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.pharmacy_order.update.success', pharmacyOrder);
});

/**
 * Delete pharmacy order (soft delete)
 * DELETE /api/v1/pharmacy-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePharmacyOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await pharmacyOrderService.deletePharmacyOrder(id, userId, ipAddress, req.user || {});

  sendNoContent(res);
});

/**
 * Dispense pharmacy order
 * POST /api/v1/pharmacy-orders/:id/dispense
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const dispensePharmacyOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pharmacyOrder = await pharmacyOrderService.dispensePharmacyOrder(
    id,
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.pharmacy_order.dispense.success', pharmacyOrder);
});

module.exports = {
  listPharmacyOrders,
  getPharmacyOrderById,
  createPharmacyOrder,
  updatePharmacyOrder,
  deletePharmacyOrder,
  dispensePharmacyOrder
};
