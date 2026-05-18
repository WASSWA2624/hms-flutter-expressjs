/**
 * Radiology Order module validation schemas
 *
 * @module modules/radiology-order/schemas
 * @description Zod validation schemas for radiology-order endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create radiology order body validation
 * Used for POST /radiology-orders endpoint
 */
const radiologyOrderStatusSchema = z.enum(['ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED']);
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

const newRadiologyTestSchema = z.object({
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().max(80).optional().nullable(),
  modality: imagingModalitySchema.optional().default('OTHER')
});

const requestDetailsSchema = z
  .object({
    request_mode: z.enum(['existing', 'new', 'custom']).optional(),
    standard_study_code: z.string().trim().max(80).optional().nullable(),
    body_region: z.string().trim().max(120).optional().nullable(),
    laterality: z.string().trim().max(40).optional().nullable(),
    priority: z.string().trim().max(40).optional().nullable(),
  })
  .passthrough()
  .optional()
  .nullable();

const requestedRadiologyTestSchema = z
  .object({
    radiology_test_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    new_test: newRadiologyTestSchema.optional().nullable(),
    clinical_note: z.string().trim().max(5000).optional().nullable(),
    request_details: requestDetailsSchema,
  })
  .superRefine((value, ctx) => {
    if (value.radiology_test_id || value.new_test?.name) return;
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['radiology_test_id'],
      message: 'errors.validation.required'
    });
  });

const createRadiologyOrderSchema = z.object({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema,
  radiology_test_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  requested_tests: z.array(requestedRadiologyTestSchema).optional(),
  status: radiologyOrderStatusSchema.optional().default('ORDERED'),
  ordered_at: z.string().datetime().optional()
});

/**
 * Update radiology order body validation
 * Used for PUT /radiology-orders/:id endpoint
 * All fields optional for partial updates
 */
const updateRadiologyOrderSchema = z.object({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  radiology_test_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: radiologyOrderStatusSchema.optional(),
  clinical_note: z.string().trim().max(5000).optional().nullable(),
  request_details: requestDetailsSchema,
  ordered_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Radiology Order ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id endpoints
 */
const radiologyOrderIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List radiology orders query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with radiology-order-specific filters
 */
const listRadiologyOrdersQuerySchema = listQuerySchema.extend({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  radiology_test_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: radiologyOrderStatusSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRadiologyOrderSchema,
  updateRadiologyOrderSchema,
  radiologyOrderIdParamsSchema,
  listRadiologyOrdersQuerySchema
};
