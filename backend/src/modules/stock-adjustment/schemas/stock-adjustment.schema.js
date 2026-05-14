/**
 * Stock adjustment module validation schemas
 */

const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createStockAdjustmentSchema = z.object({
  inventory_item_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  quantity: z.number().int(),
  reason: z.enum(['DAMAGED', 'EXPIRED', 'LOST', 'FOUND', 'CORRECTION', 'OTHER']),
  adjusted_at: z.string().datetime().optional()
});

const updateStockAdjustmentSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  quantity: z.number().int().optional(),
  reason: z.enum(['DAMAGED', 'EXPIRED', 'LOST', 'FOUND', 'CORRECTION', 'OTHER']).optional(),
  adjusted_at: z.string().datetime().optional()
});

const stockAdjustmentIdParamsSchema = z.object({
  id: uuidSchema
});

const listStockAdjustmentsQuerySchema = listQuerySchema.extend({
  inventory_item_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  reason: z.enum(['DAMAGED', 'EXPIRED', 'LOST', 'FOUND', 'CORRECTION', 'OTHER']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createStockAdjustmentSchema,
  updateStockAdjustmentSchema,
  stockAdjustmentIdParamsSchema,
  listStockAdjustmentsQuerySchema
};
