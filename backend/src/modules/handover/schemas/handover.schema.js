const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const createHandoverSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  from_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  to_user_id: uuidOrFriendlyIdentifierSchema,
  items_json: z.union([z.object({}).passthrough(), z.array(z.any())]).optional().nullable(),
  signoff_notes: z.string().trim().max(10000).optional().nullable(),
});

const updateHandoverSchema = z.object({
  to_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  items_json: z.union([z.object({}).passthrough(), z.array(z.any())]).optional().nullable(),
  signoff_notes: z.string().trim().max(10000).optional().nullable(),
});

const acceptHandoverSchema = z.object({
  accepted_notes: z.string().trim().max(10000).optional().nullable(),
});

const handoverIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listHandoversQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  from_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  to_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['PENDING', 'ACCEPTED', 'REJECTED']).optional(),
});

module.exports = {
  acceptHandoverSchema,
  createHandoverSchema,
  handoverIdParamsSchema,
  listHandoversQuerySchema,
  updateHandoverSchema,
};
