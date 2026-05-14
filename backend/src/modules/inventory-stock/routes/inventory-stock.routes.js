/**
 * Inventory stock routes
 *
 * @module modules/inventory-stock/routes
 * @description Inventory stock endpoints mounted at /api/v1/inventory-stocks
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const inventoryStockController = require('@controllers/inventory-stock/inventory-stock.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createInventoryStockSchema,
  updateInventoryStockSchema,
  inventoryStockIdParamsSchema,
  listInventoryStocksQuerySchema
} = require('@validations/inventory-stock/inventory-stock.schema');

/**
 * @description List inventory stocks with pagination and filters
 * @method GET
 * @route /api/v1/inventory-stocks/
 */
router.get(
  '/',  validateRequest({ query: listInventoryStocksQuerySchema }),

  authenticate(),
  inventoryStockController.listInventoryStocks
);

/**
 * @description Get inventory stock by ID
 * @method GET
 * @route /api/v1/inventory-stocks/:id
 */
router.get(
  '/:id',  validateRequest({ params: inventoryStockIdParamsSchema }),

  authenticate(),
  inventoryStockController.getInventoryStockById
);

/**
 * @description Create new inventory stock
 * @method POST
 * @route /api/v1/inventory-stocks/
 */
router.post(
  '/',  validateRequest({ body: createInventoryStockSchema }),

  authenticate(),
  inventoryStockController.createInventoryStock
);

/**
 * @description Update inventory stock
 * @method PUT
 * @route /api/v1/inventory-stocks/:id
 */
router.put(
  '/:id',  validateRequest({ params: inventoryStockIdParamsSchema, body: updateInventoryStockSchema }),

  authenticate(),
  inventoryStockController.updateInventoryStock
);

/**
 * @description Delete inventory stock (soft delete)
 * @method DELETE
 * @route /api/v1/inventory-stocks/:id
 */
router.delete(
  '/:id',  validateRequest({ params: inventoryStockIdParamsSchema }),

  authenticate(),
  inventoryStockController.deleteInventoryStock
);

module.exports = router;
