/**
 * Billing Adjustment module validation schemas
 *
 * @module modules/billing-adjustment/schemas
 * @description Zod validation schemas for billing adjustment endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// BillingStatus enum values from Prisma schema
const BILLING_STATUS_VALUES = ['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED'];

// ==================== Body Schemas ====================

/**
 * Create billing adjustment body validation
 * Used for POST /billing-adjustments endpoint
 */
const createBillingAdjustmentSchema = z.object({
  invoice_id: uuidOrFriendlyIdentifierSchema,
  amount: z.number().finite(),
  status: z.enum(BILLING_STATUS_VALUES),
  reason: z.string().trim().max(255).optional().nullable(),
  adjusted_at: z.string().datetime().optional()
});

/**
 * Update billing adjustment body validation
 * Used for PUT /billing-adjustments/:id endpoint
 * All fields optional for partial updates
 */
const updateBillingAdjustmentSchema = z.object({
  amount: z.number().finite().optional(),
  status: z.enum(BILLING_STATUS_VALUES).optional(),
  reason: z.string().trim().max(255).optional().nullable(),
  adjusted_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Billing Adjustment ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const billingAdjustmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List billing adjustments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with billing adjustment-specific filters
 */
const listBillingAdjustmentsQuerySchema = listQuerySchema.extend({
  invoice_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(BILLING_STATUS_VALUES).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createBillingAdjustmentSchema,
  updateBillingAdjustmentSchema,
  billingAdjustmentIdParamsSchema,
  listBillingAdjustmentsQuerySchema
};
