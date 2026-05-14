/**
 * Stock adjustment routes
 */

const express = require('express');
const router = express.Router();
const stockAdjustmentController = require('@controllers/stock-adjustment/stock-adjustment.controller');
const validate = require('@middlewares/validate.middleware');
const {
  createStockAdjustmentSchema,
  updateStockAdjustmentSchema,
  stockAdjustmentIdParamsSchema,
  listStockAdjustmentsQuerySchema
} = require('@validations/stock-adjustment/stock-adjustment.schema');

router.get('/', validate({ query: listStockAdjustmentsQuerySchema }), stockAdjustmentController.listStockAdjustments);
router.get('/:id', validate({ params: stockAdjustmentIdParamsSchema }), stockAdjustmentController.getStockAdjustment);
router.post('/', validate({ body: createStockAdjustmentSchema }), stockAdjustmentController.createStockAdjustment);
router.put('/:id', validate({ params: stockAdjustmentIdParamsSchema, body: updateStockAdjustmentSchema }), stockAdjustmentController.updateStockAdjustment);
router.delete('/:id', validate({ params: stockAdjustmentIdParamsSchema }), stockAdjustmentController.deleteStockAdjustment);

module.exports = router;
