const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const createCloseoutPackSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_close_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  day_close_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  handover_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  custody_snapshot_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  format: z.enum(['PDF', 'CSV', 'JSON', 'XLSX']).optional(),
  parameter_overrides_json: z.object({}).passthrough().optional().nullable(),
});

const closeoutPackIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listCloseoutPacksQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  generated_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['QUEUED', 'PROCESSING', 'READY', 'FAILED']).optional(),
  format: z.enum(['PDF', 'CSV', 'JSON', 'XLSX']).optional(),
});

module.exports = {
  closeoutPackIdParamsSchema,
  createCloseoutPackSchema,
  listCloseoutPacksQuerySchema,
};
