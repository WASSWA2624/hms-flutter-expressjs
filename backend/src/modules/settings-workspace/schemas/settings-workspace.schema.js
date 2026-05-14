const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const settingsWorkspaceGroupSchema = z.enum([
  'organization',
  'usersAndAccess',
  'security',
]);

const settingsWorkspaceStateSchema = z.enum([
  'configured',
  'empty',
  'attention',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  group: settingsWorkspaceGroupSchema.optional(),
  search: z.string().trim().max(120).optional(),
  state: settingsWorkspaceStateSchema.optional(),
  actionable_only: z.enum(['true', 'false']).optional(),
});

const referenceDataQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
});

module.exports = {
  referenceDataQuerySchema,
  settingsWorkspaceGroupSchema,
  settingsWorkspaceStateSchema,
  workspaceQuerySchema,
};
