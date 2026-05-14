/**
 * Referral module validation schemas
 *
 * @module modules/referral/schemas
 * @description Zod validation schemas for referral endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidSchema,
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
} = require('@lib/validation/zod');

const REFERRAL_STATUS_VALUES = ['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

const optionalText = (max = 10000) =>
  z.string().trim().max(max).optional().nullable();

// ==================== Body Schemas ====================

/**
 * Create referral body validation
 * Used for POST /referrals endpoint
 */
const createReferralSchema = z.object({
  encounter_id: uuidOrFriendlyIdentifierSchema,
  external_facility_name: z.string().trim().min(1).max(255),
  reason: z.string().trim().min(1).max(10000),
  referral_reason_code: z.string().trim().max(80).optional().nullable(),
  custom_reason: z.string().trim().max(255).optional().nullable(),
  notes: optionalText(10000),
  from_department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  to_department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(REFERRAL_STATUS_VALUES).optional(),
});

/**
 * Update referral body validation
 * Used for PUT /referrals/:id endpoint
 * All fields optional for partial updates
 */
const updateReferralSchema = z.object({
  external_facility_name: z.string().trim().min(1).max(255).optional(),
  reason: z.string().trim().min(1).max(10000).optional(),
  referral_reason_code: z.string().trim().max(80).optional().nullable(),
  custom_reason: z.string().trim().max(255).optional().nullable(),
  notes: optionalText(10000),
  from_department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  to_department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(REFERRAL_STATUS_VALUES).optional(),
});

/**
 * Redeem referral body validation
 * Used for POST /referrals/:id/redeem endpoint
 */
const redeemReferralSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable(),
});

/**
 * Referral transition action body validation
 * Used for POST /referrals/:id/approve|start|cancel endpoints
 */
const transitionReferralSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Referral ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const referralIdParamsSchema = z.object({
  id: uuidSchema,
});

// ==================== Query Params ====================

/**
 * List referrals query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with referral-specific filters
 */
const listReferralsQuerySchema = listQuerySchema.extend({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  from_department_id: uuidOrFriendlyIdentifierSchema.optional(),
  to_department_id: uuidOrFriendlyIdentifierSchema.optional(),
  external_facility_name: z.string().trim().optional(),
  referral_reason_code: z.string().trim().optional(),
  status: z.enum(REFERRAL_STATUS_VALUES).optional(),
});

module.exports = {
  createReferralSchema,
  updateReferralSchema,
  redeemReferralSchema,
  transitionReferralSchema,
  referralIdParamsSchema,
  listReferralsQuerySchema,
  REFERRAL_STATUS_VALUES,
};
