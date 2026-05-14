/**
 * Inventory stock controller
 *
 * @module modules/inventory-stock/controllers
 * @description Request handlers for inventory stock endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const inventoryStockService = require('@services/inventory-stock/inventory-stock.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List inventory stocks with pagination
 * GET /api/v1/inventory-stocks
 */
const listInventoryStocks = asyncHandler(async (req, res) => {
  const {
    inventory_item_id,
    facility_id,
    min_quantity,
    max_quantity,
    below_reorder,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    inventory_item_id,
    facility_id,
    min_quantity,
    max_quantity,
    below_reorder
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await inventoryStockService.listInventoryStocks(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress,
    req.user || {}
  );

  sendPaginated(res, 'messages.inventory_stock.list.success', result.inventoryStocks, result.pagination);
});

/**
 * Get inventory stock by ID
 * GET /api/v1/inventory-stocks/:id
 */
const getInventoryStockById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const inventoryStock = await inventoryStockService.getInventoryStockById(
    id,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.inventory_stock.get.success', inventoryStock);
});

/**
 * Create new inventory stock
 * POST /api/v1/inventory-stocks
 */
const createInventoryStock = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const inventoryStock = await inventoryStockService.createInventoryStock(
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 201, 'messages.inventory_stock.create.success', inventoryStock);
});

/**
 * Update inventory stock
 * PUT /api/v1/inventory-stocks/:id
 */
const updateInventoryStock = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const inventoryStock = await inventoryStockService.updateInventoryStock(
    id,
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.inventory_stock.update.success', inventoryStock);
});

/**
 * Delete inventory stock (soft delete)
 * DELETE /api/v1/inventory-stocks/:id
 */
const deleteInventoryStock = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await inventoryStockService.deleteInventoryStock(id, userId, ipAddress, req.user || {});

  sendNoContent(res);
});

module.exports = {
  listInventoryStocks,
  getInventoryStockById,
  createInventoryStock,
  updateInventoryStock,
  deleteInventoryStock
};
