/**
 * Purchase order module validation schemas
 */

const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createPurchaseOrderSchema = z.object({
  purchase_request_id: uuidSchema.optional().nullable(),
  supplier_id: uuidSchema.optional().nullable(),
  status: z.string().trim().min(1).max(60),
  ordered_at: z.string().datetime().optional()
});

const updatePurchaseOrderSchema = z.object({
  purchase_request_id: uuidSchema.optional().nullable(),
  supplier_id: uuidSchema.optional().nullable(),
  status: z.string().trim().min(1).max(60).optional(),
  ordered_at: z.string().datetime().optional()
});

const purchaseOrderIdParamsSchema = z.object({
  id: uuidSchema
});

const listPurchaseOrdersQuerySchema = listQuerySchema.extend({
  purchase_request_id: uuidSchema.optional(),
  supplier_id: uuidSchema.optional(),
  status: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPurchaseOrderSchema,
  updatePurchaseOrderSchema,
  purchaseOrderIdParamsSchema,
  listPurchaseOrdersQuerySchema
};
