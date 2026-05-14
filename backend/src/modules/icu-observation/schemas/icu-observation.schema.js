/**
 * ICU Observation module validation schemas
 *
 * @module modules/icu-observation/schemas
 * @description Zod validation schemas for icu-observation endpoints.
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
 * Create ICU observation body validation
 * Used for POST /icu-observations endpoint
 */
const createIcuObservationSchema = z.object({
  icu_stay_id: uuidOrFriendlyIdentifierSchema,
  observed_at: z.string().datetime().optional(),
  observation: z.string().trim().min(1).max(5000)
});

/**
 * Update ICU observation body validation
 * Used for PUT /icu-observations/:id endpoint
 * All fields optional for partial updates
 */
const updateIcuObservationSchema = z.object({
  observed_at: z.string().datetime().optional(),
  observation: z.string().trim().min(1).max(5000).optional()
});

// ==================== URL Params ====================

/**
 * ICU Observation ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const icuObservationIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List ICU observations query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with icu-observation-specific filters
 */
const listIcuObservationsQuerySchema = listQuerySchema.extend({
  icu_stay_id: uuidOrFriendlyIdentifierSchema.optional(),
  observed_at_from: z.string().datetime().optional(),
  observed_at_to: z.string().datetime().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createIcuObservationSchema,
  updateIcuObservationSchema,
  icuObservationIdParamsSchema,
  listIcuObservationsQuerySchema
};
