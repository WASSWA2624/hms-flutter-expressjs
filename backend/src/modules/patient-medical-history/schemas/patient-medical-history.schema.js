/**
 * Patient Medical History module validation schemas
 *
 * @module modules/patient-medical-history/schemas
 * @description Zod validation schemas for patient medical history endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create patient medical history body validation
 * Used for POST /patient-medical-histories endpoint
 */
const createPatientMedicalHistorySchema = z.object({
  tenant_id: uuidSchema,
  patient_id: uuidSchema,
  condition: z.string().trim().min(1).max(255),
  diagnosis_date: isoDateSchema.optional().nullable(),
  notes: z.string().trim().optional().nullable()
});

/**
 * Update patient medical history body validation
 * Used for PUT /patient-medical-histories/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientMedicalHistorySchema = z.object({
  condition: z.string().trim().min(1).max(255).optional(),
  diagnosis_date: isoDateSchema.optional().nullable(),
  notes: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Patient Medical History ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const patientMedicalHistoryIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List patient medical histories query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with patient-medical-history-specific filters
 */
const listPatientMedicalHistoriesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  condition: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPatientMedicalHistorySchema,
  updatePatientMedicalHistorySchema,
  patientMedicalHistoryIdParamsSchema,
  listPatientMedicalHistoriesQuerySchema
};
