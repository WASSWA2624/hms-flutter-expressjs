/**
 * Emergency response module validation schemas
 *
 * @module modules/emergency-response/schemas
 * @description Zod validation schemas for emergency response endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create emergency response body validation
 * Used for POST /emergency-responses endpoint
 */
const createEmergencyResponseSchema = z.object({
  emergency_case_id: uuidOrFriendlyIdentifierSchema,
  response_at: isoDateSchema.optional(),
  notes: z.string().max(5000).optional().nullable()
});

/**
 * Update emergency response body validation
 * Used for PUT /emergency-responses/:id endpoint
 * All fields optional for partial updates
 */
const updateEmergencyResponseSchema = z.object({
  emergency_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  response_at: isoDateSchema.optional(),
  notes: z.string().max(5000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Emergency response ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const emergencyResponseIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List emergency responses query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with emergency response-specific filters
 */
const listEmergencyResponsesQuerySchema = listQuerySchema.extend({
  emergency_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(255).optional()
});

module.exports = {
  createEmergencyResponseSchema,
  updateEmergencyResponseSchema,
  emergencyResponseIdParamsSchema,
  listEmergencyResponsesQuerySchema
};
