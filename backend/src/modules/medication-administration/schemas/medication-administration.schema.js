/**
 * Medication administration module validation schemas
 *
 * @module modules/medication-administration/schemas
 * @description Zod validation schemas for medication administration endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// MedicationRoute enum values from Prisma schema
const MEDICATION_ROUTES = ['ORAL', 'IV', 'IM', 'SC', 'TOPICAL', 'INHALATION', 'RECTAL', 'OTHER'];

// ==================== Body Schemas ====================

/**
 * Create medication administration body validation
 * Used for POST /medication-administrations endpoint
 */
const createMedicationAdministrationSchema = z.object({
  admission_id: uuidSchema,
  prescription_id: uuidSchema.optional(),
  administered_at: z.string().datetime().optional(),
  dose: z.string().trim().min(1).max(80),
  unit: z.string().trim().min(1).max(40).optional(),
  route: z.enum(MEDICATION_ROUTES)
});

/**
 * Update medication administration body validation
 * Used for PUT /medication-administrations/:id endpoint
 * All fields optional for partial updates
 */
const updateMedicationAdministrationSchema = z.object({
  administered_at: z.string().datetime().optional(),
  dose: z.string().trim().min(1).max(80).optional(),
  unit: z.string().trim().min(1).max(40).optional(),
  route: z.enum(MEDICATION_ROUTES).optional()
});

// ==================== URL Params ====================

/**
 * Medication administration ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const medicationAdministrationIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List medication administrations query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with medication administration-specific filters
 */
const listMedicationAdministrationsQuerySchema = listQuerySchema.extend({
  admission_id: uuidSchema.optional(),
  prescription_id: uuidSchema.optional(),
  route: z.enum(MEDICATION_ROUTES).optional()
});

module.exports = {
  createMedicationAdministrationSchema,
  updateMedicationAdministrationSchema,
  medicationAdministrationIdParamsSchema,
  listMedicationAdministrationsQuerySchema
};
