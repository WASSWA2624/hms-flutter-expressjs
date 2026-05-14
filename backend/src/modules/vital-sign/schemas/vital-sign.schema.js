/**
 * Vital Sign module validation schemas
 *
 * @module modules/vital-sign/schemas
 * @description Zod validation schemas for vital sign endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  decimalStringSchema
} = require('@lib/validation/zod');

const VITAL_TYPE_VALUES = [
  'TEMPERATURE',
  'BLOOD_PRESSURE',
  'HEART_RATE',
  'RESPIRATORY_RATE',
  'OXYGEN_SATURATION',
  'WEIGHT',
  'HEIGHT',
  'BMI'
];

const BLOOD_PRESSURE_VALUE_REGEX = /^(\d{1,4}(?:\.\d{1,2})?)\s*\/\s*(\d{1,4}(?:\.\d{1,2})?)$/;
const NUMERIC_VALUE_REGEX = /^\d+(?:\.\d+)?$/;
const decimalInputSchema = z.union([
  z.coerce.number().nonnegative(),
  decimalStringSchema
]);

const hasNumericValue = (value) =>
  typeof value === 'string' && NUMERIC_VALUE_REGEX.test(value.trim());

const createOrUpdateVitalSchemaBase = z.object({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  vital_type: z.enum(VITAL_TYPE_VALUES).optional(),
  value: z.string().trim().min(1).max(80).optional(),
  unit: z.string().trim().max(20).optional().nullable(),
  systolic_value: decimalInputSchema.optional(),
  diastolic_value: decimalInputSchema.optional(),
  map_value: decimalInputSchema.optional(),
  recorded_at: z.string().datetime().optional()
});

// ==================== Body Schemas ====================

/**
 * Create vital sign body validation
 * Used for POST /vital-signs endpoint
 */
const createVitalSignSchema = z.object({
  encounter_id: uuidOrFriendlyIdentifierSchema,
  vital_type: z.enum(VITAL_TYPE_VALUES),
  value: z.string().trim().min(1).max(80).optional(),
  unit: z.string().trim().max(20).optional().nullable(),
  systolic_value: decimalInputSchema.optional(),
  diastolic_value: decimalInputSchema.optional(),
  map_value: decimalInputSchema.optional(),
  recorded_at: z.string().datetime().optional()
}).superRefine((value, ctx) => {
  if (value.vital_type === 'BLOOD_PRESSURE') {
    const hasStructuredComponents =
      value.systolic_value != null && value.diastolic_value != null;
    const hasLegacyValue =
      typeof value.value === 'string' && BLOOD_PRESSURE_VALUE_REGEX.test(value.value.trim());

    if (!hasStructuredComponents && !hasLegacyValue) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['systolic_value'],
        message: 'errors.validation.required'
      });
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['diastolic_value'],
        message: 'errors.validation.required'
      });
    }
    return;
  }

  if (!value.value) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['value'],
      message: 'errors.validation.required'
    });
    return;
  }

  if (!hasNumericValue(value.value)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['value'],
      message: 'errors.validation.invalid_number'
    });
  }
});

/**
 * Update vital sign body validation
 * Used for PUT /vital-signs/:id endpoint
 * All fields optional for partial updates
 */
const updateVitalSignSchema = z.object({
  ...createOrUpdateVitalSchemaBase.shape
}).superRefine((value, ctx) => {
  if (value.vital_type && value.vital_type !== 'BLOOD_PRESSURE') {
    if (!value.value) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['value'],
        message: 'errors.validation.required'
      });
      return;
    }

    if (!hasNumericValue(value.value)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['value'],
        message: 'errors.validation.invalid_number'
      });
    }
    return;
  }

  if (value.vital_type !== 'BLOOD_PRESSURE') return;

  const hasStructuredComponents =
    value.systolic_value != null && value.diastolic_value != null;
  const hasLegacyValue =
    typeof value.value === 'string' && BLOOD_PRESSURE_VALUE_REGEX.test(value.value.trim());

  if (!hasStructuredComponents && !hasLegacyValue) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['systolic_value'],
      message: 'errors.validation.required'
    });
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['diastolic_value'],
      message: 'errors.validation.required'
    });
  }
});

const deleteVitalSignSchema = z.object({
  reason: z.string().trim().min(3).max(500)
});

// ==================== URL Params ====================

/**
 * Vital sign ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const vitalSignIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List vital signs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with vital sign-specific filters
 */
const listVitalSignsQuerySchema = listQuerySchema.extend({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  vital_type: z.enum(VITAL_TYPE_VALUES).optional()
});

module.exports = {
  createVitalSignSchema,
  updateVitalSignSchema,
  deleteVitalSignSchema,
  vitalSignIdParamsSchema,
  listVitalSignsQuerySchema
};
