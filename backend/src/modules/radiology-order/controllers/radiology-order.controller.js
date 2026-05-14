/**
 * Radiology Order controller
 *
 * @module modules/radiology-order/controllers
 * @description Request handlers for radiology order endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const radiologyOrderService = require('@services/radiology-order/radiology-order.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List radiology orders with pagination
 * GET /api/v1/radiology-orders
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listRadiologyOrders = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    patient_id,
    radiology_test_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    patient_id,
    radiology_test_id,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await radiologyOrderService.listRadiologyOrders(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.radiology_order.list.success', result.radiology_orders, result.pagination);
});

/**
 * Get radiology order by ID
 * GET /api/v1/radiology-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getRadiologyOrderById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyOrder = await radiologyOrderService.getRadiologyOrderById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_order.get.success', radiologyOrder);
});

/**
 * Create new radiology order
 * POST /api/v1/radiology-orders
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createRadiologyOrder = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyOrder = await radiologyOrderService.createRadiologyOrder(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.radiology_order.create.success', radiologyOrder);
});

/**
 * Update radiology order
 * PUT /api/v1/radiology-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateRadiologyOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyOrder = await radiologyOrderService.updateRadiologyOrder(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_order.update.success', radiologyOrder);
});

/**
 * Delete radiology order (soft delete)
 * DELETE /api/v1/radiology-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteRadiologyOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await radiologyOrderService.deleteRadiologyOrder(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listRadiologyOrders,
  getRadiologyOrderById,
  createRadiologyOrder,
  updateRadiologyOrder,
  deleteRadiologyOrder
};
