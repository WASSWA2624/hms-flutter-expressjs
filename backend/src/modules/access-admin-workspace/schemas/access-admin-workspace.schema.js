const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const workspaceQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  panel: z.string().trim().max(64).optional(),
  resource: z.string().trim().max(64).optional(),
  search: z.string().trim().max(255).optional(),
  status: z.string().trim().max(32).optional(),
  userId: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  roleId: uuidOrFriendlyIdentifierSchema.optional(),
  role_id: uuidOrFriendlyIdentifierSchema.optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  recordId: uuidOrFriendlyIdentifierSchema.optional(),
  page: z.coerce.number().int().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});

const referenceDataQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
});

const userIdentifierParamsSchema = z.object({
  userIdentifier: uuidOrFriendlyIdentifierSchema,
});

const resolveLegacyParamsSchema = z.object({
  resource: z.string().trim().min(1).max(64),
  id: uuidOrFriendlyIdentifierSchema,
});

module.exports = {
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  userIdentifierParamsSchema,
  workspaceQuerySchema,
};
