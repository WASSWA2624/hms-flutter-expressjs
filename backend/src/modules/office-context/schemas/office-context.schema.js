const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const jsonObjectSchema = z.object({}).passthrough();

const createOfficeContextSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  shift_id: uuidOrFriendlyIdentifierSchema,
  current_holder_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_date: z.string().trim().min(1).optional(),
  handover_due_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
  metadata_json: jsonObjectSchema.optional().nullable(),
});

const updateOfficeContextSchema = z.object({
  current_holder_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_date: z.string().trim().min(1).optional(),
  handover_due_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
  metadata_json: jsonObjectSchema.optional().nullable(),
  status: z.enum(['OPEN', 'HANDOVER_PENDING']).optional(),
});

const closeOfficeContextSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable(),
});

const officeContextIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listOfficeContextsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  current_holder_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  office_date: z.string().trim().optional(),
  status: z.enum(['OPEN', 'HANDOVER_PENDING', 'CLOSED']).optional(),
});

const currentOfficeContextQuerySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  shift_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
});

module.exports = {
  closeOfficeContextSchema,
  createOfficeContextSchema,
  currentOfficeContextQuerySchema,
  listOfficeContextsQuerySchema,
  officeContextIdParamsSchema,
  updateOfficeContextSchema,
};
