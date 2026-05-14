/**
 * Staff profile module validation schemas
 *
 * @module modules/staff-profile/schemas
 * @description Zod validation schemas for staff profile endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema,
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  decimalStringSchema
} = require('@lib/validation/zod');

const STAFF_PROFILE_FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;
const PRACTITIONER_TYPE_VALUES = ['MO', 'SPECIALIST'];

const friendlyIdSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .regex(STAFF_PROFILE_FRIENDLY_ID_REGEX, 'Invalid identifier format')
  .transform((value) => value.toUpperCase());

const resourceIdentifierSchema = z.union([uuidSchema, friendlyIdSchema]);
const decimalInputSchema = z.union([z.coerce.number().positive(), decimalStringSchema]);

// ==================== Body Schemas ====================

/**
 * Create staff profile body validation
 * Used for POST /staff-profiles endpoint
 */
const createStaffProfileSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  user_id: resourceIdentifierSchema,
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  staff_number: z.string().trim().max(80).optional().nullable(),
  position: z.string().trim().max(120).optional().nullable(),
  practitioner_type: z.enum(PRACTITIONER_TYPE_VALUES).optional().nullable(),
  consultation_fee: decimalInputSchema.optional().nullable(),
  consultation_currency: z.string().trim().min(1).max(10).optional().nullable()
    .transform((value) => (typeof value === 'string' ? value.toUpperCase() : value)),
  is_fee_overridden: z.boolean().optional(),
  hire_date: z.coerce.date().optional().nullable()
});

/**
 * Update staff profile body validation
 * Used for PUT /staff-profiles/:id endpoint
 * All fields optional for partial updates
 */
const updateStaffProfileSchema = z.object({
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  staff_number: z.string().trim().max(80).optional().nullable(),
  position: z.string().trim().max(120).optional().nullable(),
  practitioner_type: z.enum(PRACTITIONER_TYPE_VALUES).optional().nullable(),
  consultation_fee: decimalInputSchema.optional().nullable(),
  consultation_currency: z.string().trim().min(1).max(10).optional().nullable()
    .transform((value) => (typeof value === 'string' ? value.toUpperCase() : value)),
  is_fee_overridden: z.boolean().optional(),
  hire_date: z.coerce.date().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Staff profile ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const staffProfileIdParamsSchema = z.object({
  id: resourceIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List staff profiles query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with staff-profile-specific filters
 */
const listStaffProfilesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: resourceIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_number: z.string().trim().optional(),
  position: z.string().trim().optional(),
  practitioner_type: z.enum(PRACTITIONER_TYPE_VALUES).optional(),
  is_fee_overridden: z.coerce.boolean().optional(),
  has_consultation_fee: z.coerce.boolean().optional(),
  hired_from: z.coerce.date().optional(),
  hired_to: z.coerce.date().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createStaffProfileSchema,
  updateStaffProfileSchema,
  staffProfileIdParamsSchema,
  listStaffProfilesQuerySchema
};
