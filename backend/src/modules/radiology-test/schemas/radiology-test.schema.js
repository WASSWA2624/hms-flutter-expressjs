/**
 * Radiology test module validation schemas
 *
 * @module modules/radiology-test/schemas
 * @description Zod validation schemas for radiology test endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const imagingModalitySchema = z.enum([
  'XRAY',
  'CT',
  'MRI',
  'ULTRASOUND',
  'FLUOROSCOPY',
  'MAMMOGRAPHY',
  'PET',
  'NUCLEAR_MEDICINE',
  'INTERVENTIONAL_RADIOLOGY',
  'ECG',
  'ECHO',
  'ENDO',
  'GASTRO',
  'OTHER'
]);

// ==================== Body Schemas ====================

/**
 * Create radiology test body validation
 * Used for POST /radiology-tests endpoint
 */
const createRadiologyTestSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().max(80).optional().nullable(),
  modality: imagingModalitySchema
});

/**
 * Update radiology test body validation
 * Used for PUT /radiology-tests/:id endpoint
 * All fields optional for partial updates
 */
const updateRadiologyTestSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: z.string().trim().max(80).optional().nullable(),
  modality: imagingModalitySchema.optional()
});

// ==================== URL Params ====================

/**
 * Radiology test ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const radiologyTestIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List radiology tests query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with radiology-test-specific filters
 */
const listRadiologyTestsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  modality: imagingModalitySchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRadiologyTestSchema,
  updateRadiologyTestSchema,
  radiologyTestIdParamsSchema,
  listRadiologyTestsQuerySchema
};
