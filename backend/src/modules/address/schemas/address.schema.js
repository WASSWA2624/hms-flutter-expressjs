/**
 * Address module validation schemas
 *
 * @module modules/address/schemas
 * @description Zod validation schemas for address endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create address body validation
 * Used for POST /addresses endpoint
 */
const createAddressSchema = z.object({
  tenant_id: uuidSchema,
  address_type: z.enum(['HOME', 'WORK', 'BILLING', 'SHIPPING', 'OTHER']),
  line1: z.string().trim().min(1).max(255),
  line2: z.string().trim().min(1).max(255).nullable().optional(),
  city: z.string().trim().min(1).max(120).nullable().optional(),
  state: z.string().trim().min(1).max(120).nullable().optional(),
  postal_code: z.string().trim().min(1).max(40).nullable().optional(),
  country: z.string().trim().min(1).max(120).nullable().optional(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  facility_id: uuidSchema.optional().nullable(),
  branch_id: uuidSchema.optional().nullable(),
  patient_id: uuidSchema.optional().nullable(),
  user_profile_id: uuidSchema.optional().nullable(),
  staff_profile_id: uuidSchema.optional().nullable(),
  supplier_id: uuidSchema.optional().nullable()
});

/**
 * Update address body validation
 * Used for PUT /addresses/:id endpoint
 * All fields optional for partial updates
 */
const updateAddressSchema = z.object({
  address_type: z.enum(['HOME', 'WORK', 'BILLING', 'SHIPPING', 'OTHER']).optional(),
  line1: z.string().trim().min(1).max(255).optional(),
  line2: z.string().trim().min(1).max(255).nullable().optional(),
  city: z.string().trim().min(1).max(120).nullable().optional(),
  state: z.string().trim().min(1).max(120).nullable().optional(),
  postal_code: z.string().trim().min(1).max(40).nullable().optional(),
  country: z.string().trim().min(1).max(120).nullable().optional(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  facility_id: uuidSchema.optional().nullable(),
  branch_id: uuidSchema.optional().nullable(),
  patient_id: uuidSchema.optional().nullable(),
  user_profile_id: uuidSchema.optional().nullable(),
  staff_profile_id: uuidSchema.optional().nullable(),
  supplier_id: uuidSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * Address ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const addressIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List addresses query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with address-specific filters
 */
const listAddressesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  address_type: z.enum(['HOME', 'WORK', 'BILLING', 'SHIPPING', 'OTHER']).optional(),
  facility_id: uuidSchema.optional(),
  branch_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  user_profile_id: uuidSchema.optional(),
  staff_profile_id: uuidSchema.optional(),
  supplier_id: uuidSchema.optional(),
  city: z.string().trim().optional(),
  state: z.string().trim().optional(),
  country: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAddressSchema,
  updateAddressSchema,
  addressIdParamsSchema,
  listAddressesQuerySchema
};
