/**
 * Stock movement routes
 *
 * @module modules/stock-movement/routes
 * @description Stock movement endpoints mounted at /api/v1/stock-movements
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const stockMovementController = require('@controllers/stock-movement/stock-movement.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createStockMovementSchema,
  updateStockMovementSchema,
  stockMovementIdParamsSchema,
  listStockMovementsQuerySchema
} = require('@validations/stock-movement/stock-movement.schema');

/**
 * @description List stock movements with pagination and filters
 * @method GET
 * @route /api/v1/stock-movements/
 */
router.get(
  '/',  validateRequest({ query: listStockMovementsQuerySchema }),

  authenticate(),
  stockMovementController.listStockMovements
);

/**
 * @description Get stock movement by ID
 * @method GET
 * @route /api/v1/stock-movements/:id
 */
router.get(
  '/:id',  validateRequest({ params: stockMovementIdParamsSchema }),

  authenticate(),
  stockMovementController.getStockMovementById
);

/**
 * @description Create new stock movement
 * @method POST
 * @route /api/v1/stock-movements/
 */
router.post(
  '/',  validateRequest({ body: createStockMovementSchema }),

  authenticate(),
  stockMovementController.createStockMovement
);

/**
 * @description Update stock movement
 * @method PUT
 * @route /api/v1/stock-movements/:id
 */
router.put(
  '/:id',  validateRequest({ params: stockMovementIdParamsSchema, body: updateStockMovementSchema }),

  authenticate(),
  stockMovementController.updateStockMovement
);

/**
 * @description Delete stock movement (soft delete)
 * @method DELETE
 * @route /api/v1/stock-movements/:id
 */
router.delete(
  '/:id',  validateRequest({ params: stockMovementIdParamsSchema }),

  authenticate(),
  stockMovementController.deleteStockMovement
);

module.exports = router;
