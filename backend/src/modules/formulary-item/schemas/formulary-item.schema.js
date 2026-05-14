/**
 * Formulary item module validation schemas
 *
 * @module modules/formulary-item/schemas
 * @description Zod validation schemas for formulary item endpoints.
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
 * Create formulary item body validation
 * Used for POST /formulary-items endpoint
 */
const createFormularyItemSchema = z.object({
  tenant_id: uuidSchema,
  drug_id: uuidSchema,
  is_active: z.boolean().optional()
});

/**
 * Update formulary item body validation
 * Used for PUT /formulary-items/:id endpoint
 * All fields optional for partial updates
 */
const updateFormularyItemSchema = z.object({
  is_active: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Formulary item ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const formularyItemIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List formulary items query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with formulary item-specific filters
 */
const listFormularyItemsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  drug_id: uuidSchema.optional(),
  is_active: z.string().transform(val => val === 'true').optional()
});

module.exports = {
  createFormularyItemSchema,
  updateFormularyItemSchema,
  formularyItemIdParamsSchema,
  listFormularyItemsQuerySchema
};
