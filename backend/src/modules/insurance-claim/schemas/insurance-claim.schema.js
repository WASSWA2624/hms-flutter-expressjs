/**
 * Insurance claim module validation schemas
 *
 * @module modules/insurance-claim/schemas
 * @description Zod validation schemas for insurance claim endpoints.
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
 * Create insurance claim body validation
 * Used for POST /insurance-claims endpoint
 */
const createInsuranceClaimSchema = z.object({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema,
  invoice_id: uuidOrFriendlyIdentifierSchema,
  status: z.enum(['SUBMITTED', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED']).optional(),
  submitted_at: z.string().datetime().optional()
});

/**
 * Update insurance claim body validation
 * Used for PUT /insurance-claims/:id endpoint
 * All fields optional for partial updates
 */
const updateInsuranceClaimSchema = z.object({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  invoice_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['SUBMITTED', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED']).optional(),
  submitted_at: z.string().datetime().optional()
});

/**
 * Submit insurance claim body validation
 * Used for POST /insurance-claims/:id/submit endpoint
 */
const submitInsuranceClaimSchema = z.object({
  submitted_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable()
});

/**
 * Reconcile insurance claim body validation
 * Used for POST /insurance-claims/:id/reconcile endpoint
 */
const reconcileInsuranceClaimSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED', 'PAID']).optional(),
  notes: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Insurance claim ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const insuranceClaimIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List insurance claims query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with insurance-claim-specific filters
 */
const listInsuranceClaimsQuerySchema = listQuerySchema.extend({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  invoice_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['SUBMITTED', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED']).optional(),
  submitted_at_from: z.string().datetime().optional(),
  submitted_at_to: z.string().datetime().optional()
});

module.exports = {
  createInsuranceClaimSchema,
  updateInsuranceClaimSchema,
  submitInsuranceClaimSchema,
  reconcileInsuranceClaimSchema,
  insuranceClaimIdParamsSchema,
  listInsuranceClaimsQuerySchema
};
