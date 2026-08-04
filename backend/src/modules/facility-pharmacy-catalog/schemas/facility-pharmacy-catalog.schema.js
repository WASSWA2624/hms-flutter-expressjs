/**
 * Facility pharmacy catalog validation schemas
 */

const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const optionalTrimmedString = (max) =>
  z.preprocess(
    (value) => (value == null || value === '' ? null : String(value).trim()),
    z.string().max(max).nullable().optional()
  );

const upsertFacilityPharmacyOfferingSchema = z
  .object({
    tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
    facility_id: uuidOrFriendlyIdentifierSchema.optional(),
    drug_id: uuidOrFriendlyIdentifierSchema.optional(),
    is_active: z.boolean().optional(),
    sort_order: z.coerce.number().int().min(0).max(9999).optional(),
    unit_price: z.coerce.number().min(0).optional(),
    currency: optionalTrimmedString(10),
    default_storage_shelf_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  })
  .superRefine((data, ctx) => {
    if (
      data.is_active === true &&
      (data.unit_price == null || data.unit_price < 0)
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'unit_price is required when the offering is active',
        path: ['unit_price'],
      });
    }
  });

const disableFacilityPharmacyOfferingSchema = z.object({
  reason: z.string().trim().min(1).max(500),
});

const facilityPharmacyDrugParamsSchema = z.object({
  drug_id: uuidOrFriendlyIdentifierSchema,
});

const listFacilityPharmacyCatalogQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(120).optional(),
  offered_only: z.enum(['true', 'false']).optional(),
  include_inactive: z.enum(['true', 'false']).optional(),
});

module.exports = {
  upsertFacilityPharmacyOfferingSchema,
  disableFacilityPharmacyOfferingSchema,
  facilityPharmacyDrugParamsSchema,
  listFacilityPharmacyCatalogQuerySchema,
};
