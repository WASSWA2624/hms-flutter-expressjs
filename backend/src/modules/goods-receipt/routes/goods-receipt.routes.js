/**
 * Goods receipt routes
 */

const express = require('express');
const router = express.Router();
const goodsReceiptController = require('@controllers/goods-receipt/goods-receipt.controller');
const validate = require('@middlewares/validate.middleware');
const {
  createGoodsReceiptSchema,
  updateGoodsReceiptSchema,
  goodsReceiptIdParamsSchema,
  listGoodsReceiptsQuerySchema
} = require('@validations/goods-receipt/goods-receipt.schema');

router.get('/', validate({ query: listGoodsReceiptsQuerySchema }), goodsReceiptController.listGoodsReceipts);
router.get('/:id', validate({ params: goodsReceiptIdParamsSchema }), goodsReceiptController.getGoodsReceipt);
router.post('/', validate({ body: createGoodsReceiptSchema }), goodsReceiptController.createGoodsReceipt);
router.put('/:id', validate({ params: goodsReceiptIdParamsSchema, body: updateGoodsReceiptSchema }), goodsReceiptController.updateGoodsReceipt);
router.delete('/:id', validate({ params: goodsReceiptIdParamsSchema }), goodsReceiptController.deleteGoodsReceipt);

module.exports = router;
