/**
 * Lab order item controller
 *
 * @module modules/lab-order-item/controllers
 * @description Request handlers for lab order item endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const labOrderItemService = require('@services/lab-order-item/lab-order-item.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List lab order items with pagination
 * GET /api/v1/lab-order-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listLabOrderItems = asyncHandler(async (req, res) => {
  const {
    lab_order_id,
    lab_test_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    lab_order_id,
    lab_test_id,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labOrderItemService.listLabOrderItems(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_order_item.list.success', result.labOrderItems, result.pagination);
});

/**
 * Get lab order item by ID
 * GET /api/v1/lab-order-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getLabOrderItemById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labOrderItem = await labOrderItemService.getLabOrderItemById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_order_item.get.success', labOrderItem);
});

/**
 * Create new lab order item
 * POST /api/v1/lab-order-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createLabOrderItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labOrderItem = await labOrderItemService.createLabOrderItem(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_order_item.create.success', labOrderItem);
});

/**
 * Update lab order item
 * PUT /api/v1/lab-order-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateLabOrderItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labOrderItem = await labOrderItemService.updateLabOrderItem(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_order_item.update.success', labOrderItem);
});

/**
 * Delete lab order item (soft delete)
 * DELETE /api/v1/lab-order-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteLabOrderItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labOrderItemService.deleteLabOrderItem(id, userId, ipAddress);

  sendNoContent(res, 'messages.lab_order_item.delete.success');
});

module.exports = {
  listLabOrderItems,
  getLabOrderItemById,
  createLabOrderItem,
  updateLabOrderItem,
  deleteLabOrderItem
};
