/**
 * Lab test module validation schemas
 *
 * @module modules/lab-test/schemas
 * @description Zod validation schemas for lab test endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const optionalTrimmedString = (maxLength) =>
  z.string().trim().min(1).max(maxLength).optional().nullable();

const optionalIntegerSchema = z
  .union([z.number().int().nonnegative(), z.string().trim().regex(/^\d+$/)])
  .optional()
  .nullable();

const optionalDecimalSchema = z
  .union([
    z.number().finite(),
    z.string().trim().regex(/^-?\d+(?:\.\d+)?$/),
  ])
  .optional()
  .nullable();

const labReferenceGenderSchema = z.enum(['MALE', 'FEMALE', 'OTHER', 'UNKNOWN']);
const labReferenceAgeUnitSchema = z.enum(['DAY', 'WEEK', 'MONTH', 'YEAR']);
const labTestResultKindSchema = z.enum(['NUMERIC', 'QUALITATIVE', 'TEXT']);
const labResultStatusSchema = z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING']);

const labReferenceRangeSchema = z
  .object({
    label: optionalTrimmedString(120),
    unit: optionalTrimmedString(40),
    gender: labReferenceGenderSchema.optional().nullable(),
    age_min_value: optionalIntegerSchema,
    age_min_unit: labReferenceAgeUnitSchema.optional().nullable(),
    age_max_value: optionalIntegerSchema,
    age_max_unit: labReferenceAgeUnitSchema.optional().nullable(),
    normal_min_value: optionalDecimalSchema,
    normal_max_value: optionalDecimalSchema,
    critical_min_value: optionalDecimalSchema,
    critical_max_value: optionalDecimalSchema,
    reference_text: optionalTrimmedString(255),
    notes: optionalTrimmedString(255),
  })
  .superRefine((value, ctx) => {
    const hasAnyValue = Object.values(value).some(
      (entry) => entry !== null && entry !== undefined && String(entry).trim() !== ''
    );
    if (!hasAnyValue) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Reference range rows cannot be empty.',
      });
    }

    if ((value.age_min_value != null) !== (value.age_min_unit != null)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Minimum age value and unit must be provided together.',
        path: ['age_min_unit'],
      });
    }

    if ((value.age_max_value != null) !== (value.age_max_unit != null)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Maximum age value and unit must be provided together.',
        path: ['age_max_unit'],
      });
    }

    const normalMin = value.normal_min_value == null ? null : Number(value.normal_min_value);
    const normalMax = value.normal_max_value == null ? null : Number(value.normal_max_value);
    if (normalMin != null && normalMax != null && normalMin > normalMax) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Normal minimum value cannot exceed the normal maximum value.',
        path: ['normal_max_value'],
      });
    }

    const criticalMin =
      value.critical_min_value == null ? null : Number(value.critical_min_value);
    const criticalMax =
      value.critical_max_value == null ? null : Number(value.critical_max_value);
    if (criticalMin != null && criticalMax != null && criticalMin > criticalMax) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Critical minimum value cannot exceed the critical maximum value.',
        path: ['critical_max_value'],
      });
    }
  });

const labUnitOptionSchema = z.object({
  label: optionalTrimmedString(80),
  unit: z.string().trim().min(1).max(40),
  ucum_code: optionalTrimmedString(40),
  is_default: z.boolean().optional(),
});

const withUniqueUnitOptions = (schema) =>
  schema.superRefine((value, ctx) => {
    if (!Array.isArray(value.unit_options)) return;
    const seen = new Set();
    value.unit_options.forEach((entry, index) => {
      const identifier = String(entry?.unit || '').trim().toUpperCase();
      if (!identifier) return;
      if (seen.has(identifier)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Each unit can only appear once per test.',
          path: ['unit_options', index, 'unit'],
        });
        return;
      }
      seen.add(identifier);
    });
  });

const labResultOptionSchema = z.object({
  value: z.string().trim().min(1).max(80),
  label: optionalTrimmedString(120),
  aliases: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  aliases_json: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  status: labResultStatusSchema.optional(),
  result_flag: optionalTrimmedString(40),
  is_positive: z.boolean().optional(),
});

const withUniqueResultOptions = (schema) =>
  schema.superRefine((value, ctx) => {
    if (!Array.isArray(value.result_options)) return;
    const seen = new Set();
    value.result_options.forEach((entry, index) => {
      const identifier = String(entry?.value || '').trim().toUpperCase();
      if (!identifier) return;
      if (seen.has(identifier)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Each qualitative result option can only appear once per test.',
          path: ['result_options', index, 'value'],
        });
        return;
      }
      seen.add(identifier);
    });
  });

// ==================== Body Schemas ====================

/**
 * Create lab test body validation
 * Used for POST /lab-tests endpoint
 */
const createLabTestSchema = withUniqueResultOptions(withUniqueUnitOptions(z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  code: optionalTrimmedString(80),
  category: optionalTrimmedString(80),
  specimen_type: optionalTrimmedString(80),
  result_kind: labTestResultKindSchema.optional(),
  unit: optionalTrimmedString(40),
  description: optionalTrimmedString(255),
  reference_range: optionalTrimmedString(255),
  reference_ranges: z.array(labReferenceRangeSchema).max(25).optional(),
  unit_options: z.array(labUnitOptionSchema).max(20).optional(),
  result_options: z.array(labResultOptionSchema).max(20).optional(),
})));

/**
 * Update lab test body validation
 * Used for PUT /lab-tests/:id endpoint
 * All fields optional for partial updates
 */
const updateLabTestSchema = withUniqueResultOptions(withUniqueUnitOptions(z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: optionalTrimmedString(80),
  category: optionalTrimmedString(80),
  specimen_type: optionalTrimmedString(80),
  result_kind: labTestResultKindSchema.optional(),
  unit: optionalTrimmedString(40),
  description: optionalTrimmedString(255),
  reference_range: optionalTrimmedString(255),
  reference_ranges: z.array(labReferenceRangeSchema).max(25).optional(),
  unit_options: z.array(labUnitOptionSchema).max(20).optional(),
  result_options: z.array(labResultOptionSchema).max(20).optional(),
})));

// ==================== URL Params ====================

/**
 * Lab test ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const labTestIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List lab tests query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with lab test-specific filters
 */
const listLabTestsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  category: z.string().trim().optional(),
  specimen_type: z.string().trim().optional(),
  result_kind: labTestResultKindSchema.optional(),
  include_pending_review: z.union([z.boolean(), z.string().trim()]).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createLabTestSchema,
  updateLabTestSchema,
  labTestIdParamsSchema,
  listLabTestsQuerySchema
};
