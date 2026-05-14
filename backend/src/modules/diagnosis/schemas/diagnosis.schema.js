/**
 * Diagnosis module validation schemas
 *
 * @module modules/diagnosis/schemas
 * @description Zod validation schemas for diagnosis endpoints.
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
 * Create diagnosis body validation
 * Used for POST /diagnoses endpoint
 */
const createDiagnosisSchema = z.object({
  encounter_id: uuidSchema,
  diagnosis_type: z.enum(['PRIMARY', 'SECONDARY', 'DIFFERENTIAL']),
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(65535)
});

/**
 * Update diagnosis body validation
 * Used for PUT /diagnoses/:id endpoint
 * All fields optional for partial updates
 */
const updateDiagnosisSchema = z.object({
  diagnosis_type: z.enum(['PRIMARY', 'SECONDARY', 'DIFFERENTIAL']).optional(),
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(65535).optional()
});

// ==================== URL Params ====================

/**
 * Diagnosis ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const diagnosisIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List diagnoses query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with diagnosis-specific filters
 */
const listDiagnosesQuerySchema = listQuerySchema.extend({
  encounter_id: uuidSchema.optional(),
  diagnosis_type: z.enum(['PRIMARY', 'SECONDARY', 'DIFFERENTIAL']).optional(),
  code: z.string().trim().optional()
});

module.exports = {
  createDiagnosisSchema,
  updateDiagnosisSchema,
  diagnosisIdParamsSchema,
  listDiagnosesQuerySchema
};
