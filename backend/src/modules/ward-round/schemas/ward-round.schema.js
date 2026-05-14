/**
 * Ward Round module validation schemas
 *
 * @module modules/ward-round/schemas
 * @description Zod validation schemas for ward round endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create ward round body validation
 * Used for POST /ward-rounds endpoint
 */
const createWardRoundSchema = z.object({
  admission_id: uuidSchema,
  round_at: isoDateSchema.optional(),
  notes: z.string().trim().optional().nullable()
});

/**
 * Update ward round body validation
 * Used for PUT /ward-rounds/:id endpoint
 * All fields optional for partial updates
 */
const updateWardRoundSchema = z.object({
  round_at: isoDateSchema.optional(),
  notes: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Ward Round ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const wardRoundIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List ward rounds query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with ward round-specific filters
 */
const listWardRoundsQuerySchema = listQuerySchema.extend({
  admission_id: uuidSchema.optional()
});

module.exports = {
  createWardRoundSchema,
  updateWardRoundSchema,
  wardRoundIdParamsSchema,
  listWardRoundsQuerySchema
};
