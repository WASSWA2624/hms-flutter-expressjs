/**
 * Patient Identifier module validation schemas
 *
 * @module modules/patient-identifier/schemas
 * @description Zod validation schemas for patient-identifier endpoints.
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
 * Create patient identifier body validation
 * Used for POST /patient-identifiers endpoint
 */
const createPatientIdentifierSchema = z.object({
  tenant_id: uuidSchema,
  patient_id: uuidSchema,
  identifier_type: z.string().trim().min(1).max(80),
  identifier_value: z.string().trim().min(1).max(120),
  is_primary: z.boolean().optional()
});

/**
 * Update patient identifier body validation
 * Used for PUT /patient-identifiers/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientIdentifierSchema = z.object({
  identifier_type: z.string().trim().min(1).max(80).optional(),
  identifier_value: z.string().trim().min(1).max(120).optional(),
  is_primary: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Patient Identifier ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const patientIdentifierIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List patient identifiers query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with patient-identifier-specific filters
 */
const listPatientIdentifiersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  identifier_type: z.string().trim().optional(),
  identifier_value: z.string().trim().optional(),
  is_primary: z.string().transform(val => val === 'true').optional()
});

module.exports = {
  createPatientIdentifierSchema,
  updatePatientIdentifierSchema,
  patientIdentifierIdParamsSchema,
  listPatientIdentifiersQuerySchema
};
