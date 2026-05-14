/**
 * Subscription module validation schemas
 *
 * @module modules/subscription/schemas
 * @description Zod validation schemas for subscription endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const subscriptionStatusSchema = z.enum([
  'ACTIVE',
  'PAST_DUE',
  'CANCELLED',
  'TRIAL',
]);
const jsonObjectSchema = z.record(z.string(), z.unknown());

// ==================== Body Schemas ====================

/**
 * Create subscription body validation
 * Used for POST /subscriptions endpoint
 */
const createSubscriptionSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  plan_id: uuidOrFriendlyIdentifierSchema,
  pending_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: subscriptionStatusSchema.optional(),
  start_date: z.string().datetime().optional(),
  end_date: z.string().datetime().optional().nullable(),
  entitlement_snapshot_json: jsonObjectSchema.optional().nullable(),
  extension_json: jsonObjectSchema.optional().nullable(),
});

/**
 * Update subscription body validation
 * Used for PUT /subscriptions/:id endpoint
 * All fields optional for partial updates
 */
const updateSubscriptionSchema = z.object({
  plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  pending_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: subscriptionStatusSchema.optional(),
  start_date: z.string().datetime().optional(),
  end_date: z.string().datetime().optional().nullable(),
  entitlement_snapshot_json: jsonObjectSchema.optional().nullable(),
  extension_json: jsonObjectSchema.optional().nullable(),
});

/**
 * Upgrade/downgrade request schema
 */
const changeSubscriptionPlanSchema = z.object({
  target_plan_id: uuidOrFriendlyIdentifierSchema,
  effective_at: z.string().datetime().optional().nullable(),
  reason: z.string().trim().max(10000).optional().nullable()
});

/**
 * Renew subscription schema
 */
const renewSubscriptionSchema = z.object({
  end_date: z.string().datetime().optional().nullable(),
  reason: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Subscription ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const subscriptionIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List subscriptions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with subscription-specific filters
 */
const listSubscriptionsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: subscriptionStatusSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createSubscriptionSchema,
  updateSubscriptionSchema,
  changeSubscriptionPlanSchema,
  renewSubscriptionSchema,
  subscriptionIdParamsSchema,
  listSubscriptionsQuerySchema
};
