const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const dashboardPanelSchema = z.enum([
  'overview',
  'queue',
  'activity',
  'insights',
  'getting-started',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: dashboardPanelSchema.optional(),
  queue: z.string().trim().max(80).optional(),
  search: z.string().trim().max(160).optional(),
  status: z.string().trim().max(80).optional(),
  module: z.string().trim().max(80).optional(),
  event_type: z.string().trim().max(80).optional(),
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branchId: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  datePreset: z.string().trim().max(80).optional(),
  date_preset: z.string().trim().max(80).optional(),
  from: z.string().trim().optional(),
  to: z.string().trim().optional(),
});

const lookupsQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branchId: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
});

module.exports = {
  dashboardPanelSchema,
  lookupsQuerySchema,
  workspaceQuerySchema,
};
