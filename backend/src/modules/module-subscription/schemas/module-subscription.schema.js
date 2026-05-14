/**
 * Module subscription module validation schemas
 *
 * @module modules/module-subscription/schemas
 * @description Zod validation schemas for module subscription endpoints.
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
 * Create module subscription body validation
 * Used for POST /module-subscriptions endpoint
 */
const createModuleSubscriptionSchema = z.object({
  module_id: uuidOrFriendlyIdentifierSchema,
  subscription_id: uuidOrFriendlyIdentifierSchema,
  is_active: z.boolean().optional()
});

/**
 * Update module subscription body validation
 * Used for PUT /module-subscriptions/:id endpoint
 * All fields optional for partial updates
 */
const updateModuleSubscriptionSchema = z.object({
  module_id: uuidOrFriendlyIdentifierSchema.optional(),
  subscription_id: uuidOrFriendlyIdentifierSchema.optional(),
  is_active: z.boolean().optional()
});

/**
 * Activate/deactivate request schema
 */
const moduleSubscriptionActivationSchema = z.object({
  reason: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Module subscription ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const moduleSubscriptionIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List module subscriptions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with module subscription-specific filters
 */
const listModuleSubscriptionsQuerySchema = listQuerySchema.extend({
  module_id: uuidOrFriendlyIdentifierSchema.optional(),
  subscription_id: uuidOrFriendlyIdentifierSchema.optional(),
  is_active: z.enum(['true', 'false']).optional()
});

module.exports = {
  createModuleSubscriptionSchema,
  updateModuleSubscriptionSchema,
  moduleSubscriptionActivationSchema,
  moduleSubscriptionIdParamsSchema,
  listModuleSubscriptionsQuerySchema
};
