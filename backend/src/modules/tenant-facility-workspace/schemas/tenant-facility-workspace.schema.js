const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const setupQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  include_deleted: z.enum(['true', 'false']).optional(),
});

const facilityLogoParamsSchema = z.object({
  facilityId: uuidOrFriendlyIdentifierSchema,
});

module.exports = {
  setupQuerySchema,
  facilityLogoParamsSchema,
};
