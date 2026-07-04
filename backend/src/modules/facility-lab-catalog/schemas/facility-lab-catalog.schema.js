/**
 * Facility lab catalog validation schemas
 */

const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const optionalTrimmedString = (max) =>
  z.preprocess(
    (value) => (value == null || value === '' ? null : String(value).trim()),
    z.string().max(max).nullable().optional()
  );

const labResultKindSchema = z.enum(['NUMERIC', 'QUALITATIVE', 'TEXT']);
const labReferenceAgeUnitSchema = z.enum(['DAY', 'WEEK', 'MONTH', 'YEAR']);
const genderSchema = z.enum(['MALE', 'FEMALE', 'OTHER', 'UNKNOWN']);
const labResultStatusSchema = z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING', 'VERIFIED', 'REJECTED']);

const labReferenceRangeSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  label: optionalTrimmedString(120),
  unit: optionalTrimmedString(40),
  gender: genderSchema.optional().nullable(),
  age_min_value: z.coerce.number().int().min(0).max(150).optional().nullable(),
  age_min_unit: labReferenceAgeUnitSchema.optional().nullable(),
  age_max_value: z.coerce.number().int().min(0).max(150).optional().nullable(),
  age_max_unit: labReferenceAgeUnitSchema.optional().nullable(),
  normal_min_value: z.coerce.number().optional().nullable(),
  normal_max_value: z.coerce.number().optional().nullable(),
  critical_min_value: z.coerce.number().optional().nullable(),
  critical_max_value: z.coerce.number().optional().nullable(),
  reference_text: optionalTrimmedString(255),
  notes: optionalTrimmedString(255),
});

const labUnitOptionSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  label: optionalTrimmedString(80),
  unit: z.string().trim().min(1).max(40),
  ucum_code: optionalTrimmedString(40),
  is_default: z.boolean().optional(),
});

const labResultOptionSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  value: z.string().trim().min(1).max(80),
  label: optionalTrimmedString(120),
  aliases: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  aliases_json: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  status: labResultStatusSchema.optional(),
  result_flag: optionalTrimmedString(40),
  is_positive: z.boolean().optional(),
});

const upsertFacilityLabTestOfferingSchema = z
  .object({
    tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
    facility_id: uuidOrFriendlyIdentifierSchema.optional(),
    lab_test_id: uuidOrFriendlyIdentifierSchema.optional(),
    is_active: z.boolean().optional().default(true),
    sort_order: z.coerce.number().int().min(0).max(9999).optional().default(0),
    unit_price: z.coerce.number().min(0).optional(),
    currency: optionalTrimmedString(10),
  specimen_type: optionalTrimmedString(80),
  result_kind: labResultKindSchema.optional().nullable(),
  unit: optionalTrimmedString(40),
  description: optionalTrimmedString(255),
  reference_range: optionalTrimmedString(255),
  reference_ranges: z.array(labReferenceRangeSchema).max(20).optional(),
  unit_options: z.array(labUnitOptionSchema).max(20).optional(),
  result_options: z.array(labResultOptionSchema).max(40).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.is_active !== false && (data.unit_price == null || data.unit_price < 0)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'unit_price is required when the offering is active',
        path: ['unit_price'],
      });
    }
  });

const upsertFacilityLabPanelOfferingSchema = z
  .object({
    tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
    facility_id: uuidOrFriendlyIdentifierSchema.optional(),
    lab_panel_id: uuidOrFriendlyIdentifierSchema.optional(),
    is_active: z.boolean().optional().default(true),
    sort_order: z.coerce.number().int().min(0).max(9999).optional().default(0),
    unit_price: z.coerce.number().min(0).optional(),
    currency: optionalTrimmedString(10),
  })
  .superRefine((data, ctx) => {
    if (data.is_active !== false && (data.unit_price == null || data.unit_price < 0)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'unit_price is required when the offering is active',
        path: ['unit_price'],
      });
    }
  });

const disableFacilityLabOfferingSchema = z.object({
  reason: z.string().trim().min(1).max(500),
});

const facilityLabTestParamsSchema = z.object({
  lab_test_id: uuidOrFriendlyIdentifierSchema,
});

const facilityLabPanelParamsSchema = z.object({
  lab_panel_id: uuidOrFriendlyIdentifierSchema,
});

const listFacilityLabCatalogQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(120).optional(),
  offered_only: z.enum(['true', 'false']).optional(),
  include_inactive: z.enum(['true', 'false']).optional(),
});

const searchFacilityLabCatalogQuerySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  term_type: z.enum(['LAB_TEST', 'LAB_PANEL']),
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(25),
  offered_only: z.enum(['true', 'false']).optional().default('true'),
});

module.exports = {
  upsertFacilityLabTestOfferingSchema,
  upsertFacilityLabPanelOfferingSchema,
  disableFacilityLabOfferingSchema,
  facilityLabTestParamsSchema,
  facilityLabPanelParamsSchema,
  listFacilityLabCatalogQuerySchema,
  searchFacilityLabCatalogQuerySchema,
};
