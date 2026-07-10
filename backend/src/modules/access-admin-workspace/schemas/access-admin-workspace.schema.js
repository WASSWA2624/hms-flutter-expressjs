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
  roleScope: z.enum(['tenant', 'facility', 'all']).optional(),
  role_scope: z.enum(['tenant', 'facility', 'all']).optional(),
  userId: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  roleId: uuidOrFriendlyIdentifierSchema.optional(),
  role_id: uuidOrFriendlyIdentifierSchema.optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  recordId: uuidOrFriendlyIdentifierSchema.optional(),
  page: z.coerce.number().int().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  include_deleted: z.enum(['true', 'false']).optional(),
  includeDeleted: z.enum(['true', 'false']).optional(),
  lean: z.enum(['true', 'false', '1', '0']).optional(),
  all_facilities: z.enum(['true', 'false', '1', '0']).optional(),
  allFacilities: z.enum(['true', 'false', '1', '0']).optional(),
  facility_scope: z.enum(['all', 'facility']).optional(),
  facilityScope: z.enum(['all', 'facility']).optional(),
  all_tenants: z.enum(['true', 'false', '1', '0']).optional(),
  allTenants: z.enum(['true', 'false', '1', '0']).optional(),
  tenant_scope: z.enum(['all', 'tenant']).optional(),
  tenantScope: z.enum(['all', 'tenant']).optional(),
});

const referenceDataQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  include: z.string().trim().max(255).optional(),
  resources: z.string().trim().max(255).optional(),
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
