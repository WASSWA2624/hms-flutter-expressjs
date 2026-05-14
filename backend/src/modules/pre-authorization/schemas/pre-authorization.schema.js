/**
 * Pre-authorization module validation schemas
 *
 * @module modules/pre-authorization/schemas
 * @description Zod validation schemas for pre-authorization endpoints.
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
 * Create pre-authorization body validation
 * Used for POST /pre-authorizations endpoint
 */
const createPreAuthorizationSchema = z.object({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema,
  status: z.enum(['PENDING', 'APPROVED', 'DENIED', 'EXPIRED']).optional(),
  requested_at: z.string().datetime().optional(),
  approved_at: z.string().datetime().optional().nullable()
});

/**
 * Update pre-authorization body validation
 * Used for PUT /pre-authorizations/:id endpoint
 * All fields optional for partial updates
 */
const updatePreAuthorizationSchema = z.object({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['PENDING', 'APPROVED', 'DENIED', 'EXPIRED']).optional(),
  requested_at: z.string().datetime().optional(),
  approved_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Pre-authorization ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const preAuthorizationIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List pre-authorizations query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with pre-authorization-specific filters
 */
const listPreAuthorizationsQuerySchema = listQuerySchema.extend({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['PENDING', 'APPROVED', 'DENIED', 'EXPIRED']).optional(),
  requested_at_from: z.string().datetime().optional(),
  requested_at_to: z.string().datetime().optional(),
  approved_at_from: z.string().datetime().optional(),
  approved_at_to: z.string().datetime().optional()
});

module.exports = {
  createPreAuthorizationSchema,
  updatePreAuthorizationSchema,
  preAuthorizationIdParamsSchema,
  listPreAuthorizationsQuerySchema
};
