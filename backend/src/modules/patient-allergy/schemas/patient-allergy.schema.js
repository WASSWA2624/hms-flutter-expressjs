/**
 * Patient Allergy module validation schemas
 *
 * @module modules/patient-allergy/schemas
 * @description Zod validation schemas for patient allergy endpoints.
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
 * Create patient allergy body validation
 * Used for POST /patient-allergies endpoint
 */
const createPatientAllergySchema = z.object({
  tenant_id: uuidSchema,
  patient_id: uuidSchema,
  allergen: z.string().trim().min(1).max(255),
  severity: z.enum(['MILD', 'MODERATE', 'SEVERE']),
  reaction: z.string().trim().min(1).max(255).optional().nullable(),
  notes: z.string().trim().optional().nullable()
});

/**
 * Update patient allergy body validation
 * Used for PUT /patient-allergies/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientAllergySchema = z.object({
  allergen: z.string().trim().min(1).max(255).optional(),
  severity: z.enum(['MILD', 'MODERATE', 'SEVERE']).optional(),
  reaction: z.string().trim().min(1).max(255).optional().nullable(),
  notes: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Patient Allergy ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const patientAllergyIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List patient allergies query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with patient-allergy-specific filters
 */
const listPatientAllergiesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  allergen: z.string().trim().optional(),
  severity: z.enum(['MILD', 'MODERATE', 'SEVERE']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPatientAllergySchema,
  updatePatientAllergySchema,
  patientAllergyIdParamsSchema,
  listPatientAllergiesQuerySchema
};
