/**
 * Drug module validation schemas
 *
 * @module modules/drug/schemas
 * @description Zod validation schemas for drug endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create drug body validation
 * Used for POST /drugs endpoint
 */
const createDrugSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().max(80).optional().nullable(),
  form: z.string().trim().max(80).optional().nullable(),
  strength: z.string().trim().max(80).optional().nullable()
});

/**
 * Update drug body validation
 * Used for PUT /drugs/:id endpoint
 * All fields optional for partial updates
 */
const updateDrugSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: z.string().trim().max(80).optional().nullable(),
  form: z.string().trim().max(80).optional().nullable(),
  strength: z.string().trim().max(80).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Drug ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const drugIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List drugs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with drug-specific filters
 */
const listDrugsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  form: z.string().trim().optional(),
  strength: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createDrugSchema,
  updateDrugSchema,
  drugIdParamsSchema,
  listDrugsQuerySchema
};
