/**
 * Inventory item module validation schemas
 *
 * @module modules/inventory-item/schemas
 * @description Zod validation schemas for inventory item endpoints.
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
 * Inventory category enum (matches Prisma schema)
 * Enum values: MEDICATION, SUPPLY, EQUIPMENT, OTHER
 */
const inventoryCategoryEnum = z.enum(['MEDICATION', 'SUPPLY', 'EQUIPMENT', 'OTHER']);

// ==================== Body Schemas ====================

/**
 * Create inventory item body validation
 * Used for POST /inventory-items endpoint
 */
const createInventoryItemSchema = z.object({
  tenant_id: uuidSchema,
  name: z.string().trim().min(1).max(255),
  category: inventoryCategoryEnum,
  sku: z.string().trim().max(80).optional().nullable(),
  unit: z.string().trim().max(40).optional().nullable()
});

/**
 * Update inventory item body validation
 * Used for PUT /inventory-items/:id endpoint
 * All fields optional for partial updates
 */
const updateInventoryItemSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  category: inventoryCategoryEnum.optional(),
  sku: z.string().trim().max(80).optional().nullable(),
  unit: z.string().trim().max(40).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Inventory item ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const inventoryItemIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List inventory items query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with inventory-item-specific filters
 */
const listInventoryItemsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  name: z.string().trim().optional(),
  category: inventoryCategoryEnum.optional(),
  sku: z.string().trim().optional(),
  unit: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createInventoryItemSchema,
  updateInventoryItemSchema,
  inventoryItemIdParamsSchema,
  listInventoryItemsQuerySchema,
  inventoryCategoryEnum
};
