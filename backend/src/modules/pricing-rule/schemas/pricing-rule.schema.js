/**
 * Pricing Rule module validation schemas
 *
 * @module modules/pricing-rule/schemas
 * @description Zod validation schemas for pricing rule endpoints.
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
 * Create pricing rule body validation
 * Used for POST /pricing-rules endpoint
 */
const createPricingRuleSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  description: z.string().trim().optional().nullable(),
  amount: z.number().min(0).finite(),
  currency: z.string().trim().length(3).toUpperCase(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable()
});

/**
 * Update pricing rule body validation
 * Used for PUT /pricing-rules/:id endpoint
 * All fields optional for partial updates
 */
const updatePricingRuleSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  description: z.string().trim().optional().nullable(),
  amount: z.number().min(0).finite().optional(),
  currency: z.string().trim().length(3).toUpperCase().optional(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Pricing Rule ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const pricingRuleIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List pricing rules query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with pricing rule-specific filters
 */
const listPricingRulesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  currency: z.string().trim().length(3).toUpperCase().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPricingRuleSchema,
  updatePricingRuleSchema,
  pricingRuleIdParamsSchema,
  listPricingRulesQuerySchema
};
