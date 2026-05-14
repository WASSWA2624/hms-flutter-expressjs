/**
 * Purchase order routes
 */

const express = require('express');
const router = express.Router();
const purchaseOrderController = require('@controllers/purchase-order/purchase-order.controller');
const validate = require('@middlewares/validate.middleware');
const {
  createPurchaseOrderSchema,
  updatePurchaseOrderSchema,
  purchaseOrderIdParamsSchema,
  listPurchaseOrdersQuerySchema
} = require('@validations/purchase-order/purchase-order.schema');

router.get('/', validate({ query: listPurchaseOrdersQuerySchema }), purchaseOrderController.listPurchaseOrders);
router.get('/:id', validate({ params: purchaseOrderIdParamsSchema }), purchaseOrderController.getPurchaseOrder);
router.post('/', validate({ body: createPurchaseOrderSchema }), purchaseOrderController.createPurchaseOrder);
router.put('/:id', validate({ params: purchaseOrderIdParamsSchema, body: updatePurchaseOrderSchema }), purchaseOrderController.updatePurchaseOrder);
router.delete('/:id', validate({ params: purchaseOrderIdParamsSchema }), purchaseOrderController.deletePurchaseOrder);

module.exports = router;
