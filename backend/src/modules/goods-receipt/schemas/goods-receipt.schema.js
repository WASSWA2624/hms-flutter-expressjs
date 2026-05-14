/**
 * Goods receipt module validation schemas
 */

const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createGoodsReceiptSchema = z.object({
  purchase_order_id: uuidSchema,
  received_at: z.string().datetime().optional(),
  status: z.string().trim().min(1).max(60)
});

const updateGoodsReceiptSchema = z.object({
  received_at: z.string().datetime().optional(),
  status: z.string().trim().min(1).max(60).optional()
});

const goodsReceiptIdParamsSchema = z.object({
  id: uuidSchema
});

const listGoodsReceiptsQuerySchema = listQuerySchema.extend({
  purchase_order_id: uuidSchema.optional(),
  status: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createGoodsReceiptSchema,
  updateGoodsReceiptSchema,
  goodsReceiptIdParamsSchema,
  listGoodsReceiptsQuerySchema
};
