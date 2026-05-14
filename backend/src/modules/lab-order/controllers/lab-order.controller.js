/**
 * Lab order controller
 *
 * @module modules/lab-order/controllers
 * @description Request handlers for lab order endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const labOrderService = require('@services/lab-order/lab-order.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List lab orders with pagination
 * GET /api/v1/lab-orders
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listLabOrders = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    patient_id,
    status,
    ordered_at_from,
    ordered_at_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    patient_id,
    status,
    ordered_at_from,
    ordered_at_to,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labOrderService.listLabOrders(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_order.list.success', result.labOrders, result.pagination);
});

/**
 * Get lab order by ID
 * GET /api/v1/lab-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getLabOrderById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labOrder = await labOrderService.getLabOrderById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_order.get.success', labOrder);
});

/**
 * Create new lab order
 * POST /api/v1/lab-orders
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createLabOrder = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labOrder = await labOrderService.createLabOrder(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_order.create.success', labOrder);
});

/**
 * Update lab order
 * PUT /api/v1/lab-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateLabOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labOrder = await labOrderService.updateLabOrder(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_order.update.success', labOrder);
});

/**
 * Delete lab order (soft delete)
 * DELETE /api/v1/lab-orders/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteLabOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labOrderService.deleteLabOrder(id, userId, ipAddress);

  sendNoContent(res, 'messages.lab_order.delete.success');
});

module.exports = {
  listLabOrders,
  getLabOrderById,
  createLabOrder,
  updateLabOrder,
  deleteLabOrder
};
