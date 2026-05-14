const { z } = require('zod');
const { decimalStringSchema, listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const jsonObjectSchema = z.object({}).passthrough();

const createShiftCloseSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  totals_json: jsonObjectSchema.optional().nullable(),
  reconciliation_json: jsonObjectSchema.optional().nullable(),
  expected_amount: decimalStringSchema.optional().nullable(),
  actual_amount: decimalStringSchema.optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
  evidence_json: jsonObjectSchema.optional().nullable(),
  submit: z.boolean().optional(),
  status: z.enum(['DRAFT', 'SUBMITTED']).optional(),
});

const updateShiftCloseSchema = createShiftCloseSchema.partial();

const approveShiftCloseSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable(),
});

const shiftCloseIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listShiftClosesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  office_context_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  closed_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  approved_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'SUBMITTED', 'APPROVED']).optional(),
});

module.exports = {
  approveShiftCloseSchema,
  createShiftCloseSchema,
  listShiftClosesQuerySchema,
  shiftCloseIdParamsSchema,
  updateShiftCloseSchema,
};
