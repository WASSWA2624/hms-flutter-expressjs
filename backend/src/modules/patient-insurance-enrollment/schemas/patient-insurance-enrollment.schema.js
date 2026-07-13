/**
 * Patient Insurance Enrollment module validation schemas
 *
 * @module modules/patient-insurance-enrollment/schemas
 * @description Zod validation schemas for patient insurance enrollment endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

const PatientInsuranceEnrollmentStatusEnum = z.enum([
  'ACTIVE',
  'EXPIRED',
  'SUSPENDED',
  'PENDING'
]);

const CopayTypeEnum = z.enum(['NONE', 'FIXED', 'PERCENT']);

// ==================== Body Schemas ====================

/**
 * Create patient insurance enrollment body validation
 * Used for POST /patient-insurance-enrollments endpoint
 */
const createPatientInsuranceEnrollmentSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema,
  coverage_plan_id: uuidOrFriendlyIdentifierSchema,
  member_id: z.string().trim().min(1).max(120),
  status: PatientInsuranceEnrollmentStatusEnum.optional().default('PENDING'),
  valid_from: z.string().datetime().optional().nullable(),
  valid_to: z.string().datetime().optional().nullable(),
  copay_type: CopayTypeEnum.optional().default('NONE'),
  copay_value: z.number().min(0).finite().optional().nullable(),
  is_primary: z.boolean().optional().default(true),
  notes: z.string().trim().optional().nullable(),
  extension_json: z.any().optional().nullable()
});

/**
 * Update patient insurance enrollment body validation
 * Used for PUT /patient-insurance-enrollments/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientInsuranceEnrollmentSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  member_id: z.string().trim().min(1).max(120).optional(),
  status: PatientInsuranceEnrollmentStatusEnum.optional(),
  valid_from: z.string().datetime().optional().nullable(),
  valid_to: z.string().datetime().optional().nullable(),
  copay_type: CopayTypeEnum.optional(),
  copay_value: z.number().min(0).finite().optional().nullable(),
  is_primary: z.boolean().optional(),
  notes: z.string().trim().optional().nullable(),
  extension_json: z.any().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Patient Insurance Enrollment ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and POST /:id/verify endpoints
 */
const patientInsuranceEnrollmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List patient insurance enrollments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with enrollment-specific filters
 */
const listPatientInsuranceEnrollmentsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  member_id: z.string().trim().max(120).optional(),
  status: PatientInsuranceEnrollmentStatusEnum.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPatientInsuranceEnrollmentSchema,
  updatePatientInsuranceEnrollmentSchema,
  patientInsuranceEnrollmentIdParamsSchema,
  listPatientInsuranceEnrollmentsQuerySchema,
  PatientInsuranceEnrollmentStatusEnum,
  CopayTypeEnum
};
