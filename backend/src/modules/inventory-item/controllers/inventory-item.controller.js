/**
 * Inventory item controller
 *
 * @module modules/inventory-item/controllers
 * @description Request handlers for inventory item endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const inventoryItemService = require('@services/inventory-item/inventory-item.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List inventory items with pagination
 * GET /api/v1/inventory-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listInventoryItems = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    category,
    sku,
    unit,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    category,
    sku,
    unit,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await inventoryItemService.listInventoryItems(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress,
    req.user || {}
  );

  sendPaginated(res, 'messages.inventory_item.list.success', result.inventoryItems, result.pagination);
});

/**
 * Get inventory item by ID
 * GET /api/v1/inventory-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getInventoryItemById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const inventoryItem = await inventoryItemService.getInventoryItemById(
    id,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.inventory_item.get.success', inventoryItem);
});

/**
 * Create new inventory item
 * POST /api/v1/inventory-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createInventoryItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const inventoryItem = await inventoryItemService.createInventoryItem(
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 201, 'messages.inventory_item.create.success', inventoryItem);
});

/**
 * Update inventory item
 * PUT /api/v1/inventory-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateInventoryItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const inventoryItem = await inventoryItemService.updateInventoryItem(
    id,
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.inventory_item.update.success', inventoryItem);
});

/**
 * Delete inventory item (soft delete)
 * DELETE /api/v1/inventory-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteInventoryItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await inventoryItemService.deleteInventoryItem(id, userId, ipAddress, req.user || {});

  sendNoContent(res);
});

module.exports = {
  listInventoryItems,
  getInventoryItemById,
  createInventoryItem,
  updateInventoryItem,
  deleteInventoryItem
};
