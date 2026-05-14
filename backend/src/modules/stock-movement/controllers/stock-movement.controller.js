/**
 * Stock movement controller
 *
 * @module modules/stock-movement/controllers
 * @description Request handlers for stock movement endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const stockMovementService = require('@services/stock-movement/stock-movement.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List stock movements with pagination
 * GET /api/v1/stock-movements
 */
const listStockMovements = asyncHandler(async (req, res) => {
  const {
    inventory_item_id,
    facility_id,
    movement_type,
    reason,
    from_date,
    to_date,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    inventory_item_id,
    facility_id,
    movement_type,
    reason,
    from_date,
    to_date
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await stockMovementService.listStockMovements(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.stock_movement.list.success', result.stockMovements, result.pagination);
});

/**
 * Get stock movement by ID
 * GET /api/v1/stock-movements/:id
 */
const getStockMovementById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const stockMovement = await stockMovementService.getStockMovementById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.stock_movement.get.success', stockMovement);
});

/**
 * Create new stock movement
 * POST /api/v1/stock-movements
 */
const createStockMovement = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const stockMovement = await stockMovementService.createStockMovement(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.stock_movement.create.success', stockMovement);
});

/**
 * Update stock movement
 * PUT /api/v1/stock-movements/:id
 */
const updateStockMovement = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const stockMovement = await stockMovementService.updateStockMovement(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.stock_movement.update.success', stockMovement);
});

/**
 * Delete stock movement (soft delete)
 * DELETE /api/v1/stock-movements/:id
 */
const deleteStockMovement = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await stockMovementService.deleteStockMovement(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listStockMovements,
  getStockMovementById,
  createStockMovement,
  updateStockMovement,
  deleteStockMovement
};
