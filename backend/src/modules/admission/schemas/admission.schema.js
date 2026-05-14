/**
 * Admission module validation schemas
 *
 * @module modules/admission/schemas
 * @description Zod validation schemas for admission endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidSchema,
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  isoDateSchema,
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create admission body validation
 * Used for POST /admissions endpoint
 */
const createAdmissionSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema,
  encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  ward_id: uuidOrFriendlyIdentifierSchema,
  room_id: uuidOrFriendlyIdentifierSchema,
  bed_id: uuidOrFriendlyIdentifierSchema,
  admitted_at: isoDateSchema.optional(),
});

/**
 * Update admission body validation
 * Used for PUT /admissions/:id endpoint
 * All fields optional for partial updates
 */
const updateAdmissionSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['ADMITTED', 'DISCHARGED', 'TRANSFERRED', 'CANCELLED']).optional(),
  admitted_at: isoDateSchema.optional(),
  discharged_at: isoDateSchema.optional().nullable(),
});

/**
 * Discharge admission body validation
 * Used for POST /admissions/:id/discharge endpoint
 */
const dischargeAdmissionSchema = z.object({
  discharged_at: isoDateSchema.optional(),
});

/**
 * Transfer admission body validation
 * Used for POST /admissions/:id/transfer endpoint
 */
const transferAdmissionSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Admission ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const admissionIdParamsSchema = z.object({
  id: uuidSchema,
});

// ==================== Query Params ====================

/**
 * List admissions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with admission-specific filters
 */
const listAdmissionsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['ADMITTED', 'DISCHARGED', 'TRANSFERRED', 'CANCELLED']).optional(),
});

module.exports = {
  createAdmissionSchema,
  updateAdmissionSchema,
  dischargeAdmissionSchema,
  transferAdmissionSchema,
  admissionIdParamsSchema,
  listAdmissionsQuerySchema,
};
