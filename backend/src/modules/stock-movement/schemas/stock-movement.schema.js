/**
 * Stock movement module validation schemas
 *
 * @module modules/stock-movement/schemas
 * @description Zod validation schemas for stock movement endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Stock movement type enum (matches Prisma schema)
 * Enum values: INBOUND, OUTBOUND, ADJUSTMENT, TRANSFER
 */
const stockMovementTypeEnum = z.enum(['INBOUND', 'OUTBOUND', 'ADJUSTMENT', 'TRANSFER']);

/**
 * Stock reason enum (matches Prisma schema)
 * Enum values: PURCHASE, DISPENSE, RETURN, DAMAGE, EXPIRY, OTHER
 */
const stockReasonEnum = z.enum(['PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER']);

// ==================== Body Schemas ====================

/**
 * Create stock movement body validation
 * Used for POST /stock-movements endpoint
 */
const createStockMovementSchema = z.object({
  inventory_item_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  movement_type: stockMovementTypeEnum,
  reason: stockReasonEnum,
  quantity: z.number().int(),
  occurred_at: z.string().datetime().optional()
});

/**
 * Update stock movement body validation
 * Used for PUT /stock-movements/:id endpoint
 * All fields optional for partial updates
 */
const updateStockMovementSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  movement_type: stockMovementTypeEnum.optional(),
  reason: stockReasonEnum.optional(),
  quantity: z.number().int().optional(),
  occurred_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Stock movement ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const stockMovementIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List stock movements query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with stock-movement-specific filters
 */
const listStockMovementsQuerySchema = listQuerySchema.extend({
  inventory_item_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  movement_type: stockMovementTypeEnum.optional(),
  reason: stockReasonEnum.optional(),
  from_date: z.string().datetime().optional(),
  to_date: z.string().datetime().optional()
});

module.exports = {
  createStockMovementSchema,
  updateStockMovementSchema,
  stockMovementIdParamsSchema,
  listStockMovementsQuerySchema,
  stockMovementTypeEnum,
  stockReasonEnum
};
