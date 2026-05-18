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

const RADIOLOGY_CATALOG_MAX_PAGE_LIMIT = 7500;
const radiologyCatalogLimitSchema = z.coerce
  .number()
  .int('Limit must be an integer')
  .positive('Limit must be a positive number')
  .max(
    RADIOLOGY_CATALOG_MAX_PAGE_LIMIT,
    `Limit cannot exceed ${RADIOLOGY_CATALOG_MAX_PAGE_LIMIT}`
  )
  .optional();
const optionalBooleanSchema = z.preprocess((value) => {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
  }
  return value;
}, z.boolean().optional());

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
  limit: radiologyCatalogLimitSchema,
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  modality: imagingModalitySchema.optional(),
  equipment: z.string().trim().optional(),
  body_region: z.string().trim().optional(),
  procedure_type: z.string().trim().optional(),
  include_standard_catalog: optionalBooleanSchema,
  search: z.string().trim().optional()
});

module.exports = {
  createRadiologyTestSchema,
  updateRadiologyTestSchema,
  radiologyTestIdParamsSchema,
  listRadiologyTestsQuerySchema
};
