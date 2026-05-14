/**
 * Terms acceptance module validation schemas
 *
 * @module modules/terms-acceptance/schemas
 * @description Zod validation schemas for terms acceptance endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 * Note: Per API spec, terms-acceptance has no PUT endpoint (no updates)
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create terms acceptance body validation
 * Used for POST /terms-acceptances endpoint
 */
const createTermsAcceptanceSchema = z.object({
  user_id: uuidSchema,
  version_label: z.string().trim().min(1).max(40)
});

// ==================== URL Params ====================

/**
 * Terms acceptance ID URL parameter validation
 * Used for GET /:id and DELETE /:id endpoints
 */
const termsAcceptanceIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List terms acceptances query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with terms acceptance-specific filters
 */
const listTermsAcceptancesQuerySchema = listQuerySchema.extend({
  user_id: uuidSchema.optional(),
  version_label: z.string().trim().optional()
});

module.exports = {
  createTermsAcceptanceSchema,
  termsAcceptanceIdParamsSchema,
  listTermsAcceptancesQuerySchema
};
