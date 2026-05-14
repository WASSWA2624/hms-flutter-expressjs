const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const {
  REPORT_FORMATS,
  REPORT_PANELS,
  REPORT_RESOURCES,
  REPORT_TRIGGER_TYPES,
} = require('@lib/reports/constants');

const panelIds = REPORT_PANELS.map((entry) => entry.id);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: z.enum(panelIds).optional(),
  resource: z.enum(REPORT_RESOURCES).optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  action: z.string().trim().min(1).max(80).optional(),
  search: z.string().trim().optional(),
  status: z.string().trim().optional(),
  format: z.enum(REPORT_FORMATS).optional(),
  dataset: z.string().trim().optional(),
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branchId: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  ownerId: uuidOrFriendlyIdentifierSchema.optional(),
  owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  trigger: z.enum(REPORT_TRIGGER_TYPES).optional(),
  datePreset: z.enum(['today', 'last_7_days', 'last_30_days', 'due', 'custom']).optional(),
  date_preset: z.enum(['today', 'last_7_days', 'last_30_days', 'due', 'custom']).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

const lookupsQuerySchema = z.object({
  facilityId: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

module.exports = {
  lookupsQuerySchema,
  workspaceQuerySchema,
};
