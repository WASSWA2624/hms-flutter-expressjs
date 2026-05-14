/**
 * Patient Document module validation schemas
 *
 * @module modules/patient-document/schemas
 * @description Zod validation schemas for patient document endpoints.
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
 * Create patient document body validation
 * Used for POST /patient-documents endpoint
 */
const createPatientDocumentSchema = z.object({
  tenant_id: uuidSchema,
  patient_id: uuidSchema,
  document_type: z.string().trim().min(1).max(120),
  storage_key: z.string().trim().min(1).max(255),
  file_name: z.string().trim().min(1).max(255).optional().nullable(),
  content_type: z.string().trim().min(1).max(120).optional().nullable()
});

/**
 * Update patient document body validation
 * Used for PUT /patient-documents/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientDocumentSchema = z.object({
  document_type: z.string().trim().min(1).max(120).optional(),
  storage_key: z.string().trim().min(1).max(255).optional(),
  file_name: z.string().trim().min(1).max(255).optional().nullable(),
  content_type: z.string().trim().min(1).max(120).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Patient Document ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const patientDocumentIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List patient documents query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with patient-document-specific filters
 */
const listPatientDocumentsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  document_type: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPatientDocumentSchema,
  updatePatientDocumentSchema,
  patientDocumentIdParamsSchema,
  listPatientDocumentsQuerySchema
};
