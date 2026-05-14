const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const mortuaryPanelSchema = z.enum([
  'overview',
  'intake',
  'storage',
  'custody',
  'release',
  'reporting',
]);

const mortuaryResourceSchema = z.enum([
  'mortuary-cases',
  'mortuary-storage-units',
  'mortuary-storage-slots',
  'mortuary-storage-assignments',
  'mortuary-custody-events',
  'mortuary-viewings',
  'mortuary-post-mortem-requests',
  'mortuary-release-authorisations',
  'mortuary-billable-events',
]);

const mortuaryQueueSchema = z.enum([
  'IDENTIFICATION_PENDING',
  'STORAGE_EXCEPTIONS',
  'RELEASE_READY',
  'UNSETTLED_BILLING',
  'POST_MORTEM_PENDING',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: mortuaryPanelSchema.optional(),
  resource: mortuaryResourceSchema.optional(),
  queue: mortuaryQueueSchema.optional(),
  search: z.string().trim().optional(),
  status: z.string().trim().min(1).max(80).optional(),
  identification_status: z.enum(['UNVERIFIED', 'PARTIAL', 'VERIFIED']).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  storage_unit_id: uuidOrFriendlyIdentifierSchema.optional(),
  storage_slot_id: uuidOrFriendlyIdentifierSchema.optional(),
  date_preset: z.enum(['today', 'next_7_days', 'overdue', 'this_month']).optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  action: z.enum(['view', 'create', 'edit', 'release', 'audit']).optional(),
});

const lookupsQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

module.exports = {
  mortuaryPanelSchema,
  mortuaryResourceSchema,
  mortuaryQueueSchema,
  workspaceQuerySchema,
  lookupsQuerySchema,
};
