/**
 * Care Plan module validation schemas
 *
 * @module modules/care-plan/schemas
 * @description Zod validation schemas for care plan endpoints.
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
 * Create care plan body validation
 * Used for POST /care-plans endpoint
 */
const createCarePlanSchema = z.object({
  encounter_id: uuidSchema,
  plan: z.string().trim().min(1),
  start_date: z.string().datetime().optional().nullable(),
  end_date: z.string().datetime().optional().nullable()
});

/**
 * Update care plan body validation
 * Used for PUT /care-plans/:id endpoint
 * All fields optional for partial updates
 */
const updateCarePlanSchema = z.object({
  encounter_id: uuidSchema.optional(),
  plan: z.string().trim().min(1).optional(),
  start_date: z.string().datetime().optional().nullable(),
  end_date: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Care plan ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const carePlanIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List care plans query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with care plan-specific filters
 */
const listCarePlansQuerySchema = listQuerySchema.extend({
  encounter_id: uuidSchema.optional(),
  start_date: z.string().datetime().optional(),
  end_date: z.string().datetime().optional()
});

module.exports = {
  createCarePlanSchema,
  updateCarePlanSchema,
  carePlanIdParamsSchema,
  listCarePlansQuerySchema
};
