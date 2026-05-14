/**
 * Inventory stock module validation schemas
 *
 * @module modules/inventory-stock/schemas
 * @description Zod validation schemas for inventory stock endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create inventory stock body validation
 * Used for POST /inventory-stocks endpoint
 */
const createInventoryStockSchema = z.object({
  inventory_item_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  quantity: z.number().int().min(0),
  reorder_level: z.number().int().min(0).default(0)
});

/**
 * Update inventory stock body validation
 * Used for PUT /inventory-stocks/:id endpoint
 * All fields optional for partial updates
 */
const updateInventoryStockSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  quantity: z.number().int().min(0).optional(),
  reorder_level: z.number().int().min(0).optional()
});

// ==================== URL Params ====================

/**
 * Inventory stock ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const inventoryStockIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List inventory stocks query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with inventory-stock-specific filters
 */
const listInventoryStocksQuerySchema = listQuerySchema.extend({
  inventory_item_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  min_quantity: z.string().regex(/^\d+$/).transform(Number).optional(),
  max_quantity: z.string().regex(/^\d+$/).transform(Number).optional(),
  below_reorder: z.enum(['true', 'false']).transform(val => val === 'true').optional()
});

module.exports = {
  createInventoryStockSchema,
  updateInventoryStockSchema,
  inventoryStockIdParamsSchema,
  listInventoryStocksQuerySchema
};
