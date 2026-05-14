/**
 * Patient Guardian module validation schemas
 *
 * @module modules/patient-guardian/schemas
 * @description Zod validation schemas for patient-guardian endpoints.
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
 * Create patient guardian body validation
 * Used for POST /patient-guardians endpoint
 */
const createPatientGuardianSchema = z.object({
  tenant_id: uuidSchema,
  patient_id: uuidSchema,
  name: z.string().trim().min(1).max(255),
  relationship: z.string().trim().max(120).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  email: z.string().trim().email().max(255).optional().nullable()
});

/**
 * Update patient guardian body validation
 * Used for PUT /patient-guardians/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientGuardianSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  relationship: z.string().trim().max(120).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  email: z.string().trim().email().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Patient Guardian ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const patientGuardianIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List patient guardians query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with patient-guardian-specific filters
 */
const listPatientGuardiansQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  name: z.string().trim().optional(),
  relationship: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPatientGuardianSchema,
  updatePatientGuardianSchema,
  patientGuardianIdParamsSchema,
  listPatientGuardiansQuerySchema
};
