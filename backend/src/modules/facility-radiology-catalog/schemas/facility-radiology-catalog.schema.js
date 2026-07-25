/**
 * Facility radiology catalog validation schemas
 */

const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const standardRadiologyTestIdentifierSchema = z
  .string()
  .trim()
  .regex(/^STD_RAD_TEST_[A-Za-z0-9_-]+$/, 'Invalid standard radiology test identifier')
  .transform((value) => value.toUpperCase());

const facilityRadiologyTestIdentifierSchema = z.union([
  uuidOrFriendlyIdentifierSchema,
  standardRadiologyTestIdentifierSchema,
]);

const optionalTrimmedString = (max) =>
  z.preprocess(
    (value) => (value == null || value === '' ? null : String(value).trim()),
    z.string().max(max).nullable().optional()
  );

const upsertFacilityRadiologyTestOfferingSchema = z
  .object({
    tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
    facility_id: uuidOrFriendlyIdentifierSchema.optional(),
    radiology_procedure_id: facilityRadiologyTestIdentifierSchema.optional(),
    radiology_test_id: facilityRadiologyTestIdentifierSchema.optional(),
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

const disableFacilityRadiologyOfferingSchema = z.object({
  reason: z.string().trim().min(1).max(500),
});

const facilityRadiologyTestParamsSchema = z.object({
  radiology_procedure_id: facilityRadiologyTestIdentifierSchema.optional(),
  radiology_test_id: facilityRadiologyTestIdentifierSchema.optional(),
});

const listFacilityRadiologyCatalogQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(120).optional(),
  offered_only: z.enum(['true', 'false']).optional(),
  include_inactive: z.enum(['true', 'false']).optional(),
});

const searchFacilityRadiologyCatalogQuerySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  term_type: z.enum(['RADIOLOGY_TEST']).optional().default('RADIOLOGY_TEST'),
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(25),
  offered_only: z.enum(['true', 'false']).optional().default('true'),
});

module.exports = {
  upsertFacilityRadiologyTestOfferingSchema,
  disableFacilityRadiologyOfferingSchema,
  facilityRadiologyTestParamsSchema,
  listFacilityRadiologyCatalogQuerySchema,
  searchFacilityRadiologyCatalogQuerySchema,
};
