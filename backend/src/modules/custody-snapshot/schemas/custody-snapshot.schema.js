const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const jsonPayloadSchema = z.union([z.object({}).passthrough(), z.array(z.any())]);

const createCustodySnapshotSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  asset_snapshot_json: jsonPayloadSchema.optional().nullable(),
  cash_drawer_snapshot_json: jsonPayloadSchema.optional().nullable(),
  controlled_items_json: jsonPayloadSchema.optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const updateCustodySnapshotSchema = createCustodySnapshotSchema.partial();

const finalizeCustodySnapshotSchema = updateCustodySnapshotSchema;

const custodySnapshotIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listCustodySnapshotsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  captured_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'FINALIZED']).optional(),
});

module.exports = {
  createCustodySnapshotSchema,
  custodySnapshotIdParamsSchema,
  finalizeCustodySnapshotSchema,
  listCustodySnapshotsQuerySchema,
  updateCustodySnapshotSchema,
};
