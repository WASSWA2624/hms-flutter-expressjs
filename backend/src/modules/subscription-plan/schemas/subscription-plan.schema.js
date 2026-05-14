/**
 * Subscription Plan module validation schemas
 *
 * @module modules/subscription-plan/schemas
 * @description Zod validation schemas for subscription plan endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const billingCycleSchema = z.enum(['MONTHLY', 'QUARTERLY', 'YEARLY']);
const jsonObjectSchema = z.record(z.string(), z.unknown());

// ==================== Body Schemas ====================

/**
 * Create subscription plan body validation
 * Used for POST /subscription-plans endpoint
 */
const createSubscriptionPlanSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().max(120).optional().nullable(),
  tier_code: z.string().trim().max(80).optional().nullable(),
  price: z.number().min(0).finite(),
  billing_cycle: billingCycleSchema,
  max_users: z.number().int().min(0).optional().nullable(),
  max_facilities: z.number().int().min(0).optional().nullable(),
  max_storage_mb: z.number().int().min(0).optional().nullable(),
  max_modules: z.number().int().min(0).optional().nullable(),
  plan_fit_warning_percent: z.number().min(0).max(100).optional().nullable(),
  limit_policy_json: jsonObjectSchema.optional().nullable(),
  add_on_eligibility_json: jsonObjectSchema.optional().nullable(),
  extension_json: jsonObjectSchema.optional().nullable(),
});

/**
 * Update subscription plan body validation
 * Used for PUT /subscription-plans/:id endpoint
 * All fields optional for partial updates
 */
const updateSubscriptionPlanSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: z.string().trim().max(120).optional().nullable(),
  tier_code: z.string().trim().max(80).optional().nullable(),
  price: z.number().min(0).finite().optional(),
  billing_cycle: billingCycleSchema.optional(),
  max_users: z.number().int().min(0).optional().nullable(),
  max_facilities: z.number().int().min(0).optional().nullable(),
  max_storage_mb: z.number().int().min(0).optional().nullable(),
  max_modules: z.number().int().min(0).optional().nullable(),
  plan_fit_warning_percent: z.number().min(0).max(100).optional().nullable(),
  limit_policy_json: jsonObjectSchema.optional().nullable(),
  add_on_eligibility_json: jsonObjectSchema.optional().nullable(),
  extension_json: jsonObjectSchema.optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Subscription Plan ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const subscriptionPlanIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List subscription plans query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with subscription plan-specific filters
 */
const listSubscriptionPlansQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  billing_cycle: billingCycleSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createSubscriptionPlanSchema,
  updateSubscriptionPlanSchema,
  subscriptionPlanIdParamsSchema,
  listSubscriptionPlansQuerySchema
};
