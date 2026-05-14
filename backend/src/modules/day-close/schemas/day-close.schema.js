const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const jsonObjectSchema = z.object({}).passthrough();

const createDayCloseSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  checklist_json: jsonObjectSchema.optional().nullable(),
  blockers_json: z.union([jsonObjectSchema, z.array(z.any())]).optional().nullable(),
  unresolved_items_json: z.union([jsonObjectSchema, z.array(z.any())]).optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
  evidence_json: jsonObjectSchema.optional().nullable(),
  submit: z.boolean().optional(),
  status: z.enum(['DRAFT', 'SUBMITTED']).optional(),
});

const updateDayCloseSchema = createDayCloseSchema.partial();

const approveDayCloseSchema = z.object({
  blockers_json: z.union([jsonObjectSchema, z.array(z.any())]).optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const dayCloseIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listDayClosesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  submitted_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  approved_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'SUBMITTED', 'APPROVED']).optional(),
});

module.exports = {
  approveDayCloseSchema,
  createDayCloseSchema,
  dayCloseIdParamsSchema,
  listDayClosesQuerySchema,
  updateDayCloseSchema,
};
