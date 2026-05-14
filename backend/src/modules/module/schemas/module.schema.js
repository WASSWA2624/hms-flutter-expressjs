/**
 * Module module validation schemas
 *
 * @module modules/module/schemas
 * @description Zod validation schemas for module endpoints.
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
const moduleGroupSchema = z
  .union([z.string().trim().min(1).max(120), z.number().int().min(0)])
  .optional()
  .nullable();

// ==================== Body Schemas ====================

/**
 * Create module body validation
 * Used for POST /modules endpoint
 */
const createModuleSchema = z.object({
  name: z.string().trim().min(1).max(120),
  slug: z.string().trim().max(120).optional().nullable(),
  description: z.string().trim().max(1000).optional().nullable(),
  module_group: moduleGroupSchema,
  minimum_plan_tier_code: z.string().trim().max(80).optional().nullable(),
  is_add_on: z.boolean().optional(),
  add_on_price: z.number().min(0).finite().optional().nullable(),
  add_on_billing_cycle: billingCycleSchema.optional().nullable(),
  entitlement_policy_json: jsonObjectSchema.optional().nullable(),
  extension_json: jsonObjectSchema.optional().nullable(),
});

/**
 * Update module body validation
 * Used for PUT /modules/:id endpoint
 * All fields optional for partial updates
 */
const updateModuleSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  slug: z.string().trim().max(120).optional().nullable(),
  description: z.string().trim().max(1000).optional().nullable(),
  module_group: moduleGroupSchema,
  minimum_plan_tier_code: z.string().trim().max(80).optional().nullable(),
  is_add_on: z.boolean().optional(),
  add_on_price: z.number().min(0).finite().optional().nullable(),
  add_on_billing_cycle: billingCycleSchema.optional().nullable(),
  entitlement_policy_json: jsonObjectSchema.optional().nullable(),
  extension_json: jsonObjectSchema.optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Module ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const moduleIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List modules query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with module-specific filters
 */
const listModulesQuerySchema = listQuerySchema.extend({
  search: z.string().trim().optional()
});

module.exports = {
  createModuleSchema,
  updateModuleSchema,
  moduleIdParamsSchema,
  listModulesQuerySchema
};
