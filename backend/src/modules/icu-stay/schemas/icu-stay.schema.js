/**
 * ICU Stay module validation schemas
 *
 * @module modules/icu-stay/schemas
 * @description Zod validation schemas for icu-stay endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create ICU stay body validation
 * Used for POST /icu-stays endpoint
 */
const createIcuStaySchema = z.object({
  admission_id: uuidOrFriendlyIdentifierSchema,
  started_at: z.string().datetime().optional(),
  ended_at: z.string().datetime().optional().nullable()
});

/**
 * Update ICU stay body validation
 * Used for PUT /icu-stays/:id endpoint
 * All fields optional for partial updates
 */
const updateIcuStaySchema = z.object({
  started_at: z.string().datetime().optional(),
  ended_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * ICU Stay ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const icuStayIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List ICU stays query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with icu-stay-specific filters
 */
const listIcuStaysQuerySchema = listQuerySchema.extend({
  admission_id: uuidOrFriendlyIdentifierSchema.optional(),
  started_at_from: z.string().datetime().optional(),
  started_at_to: z.string().datetime().optional(),
  ended_at_from: z.string().datetime().optional(),
  ended_at_to: z.string().datetime().optional(),
  is_active: z.string().transform(val => val === 'true').optional()
});

module.exports = {
  createIcuStaySchema,
  updateIcuStaySchema,
  icuStayIdParamsSchema,
  listIcuStaysQuerySchema
};
