const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const jsonObjectSchema = z.object({}).passthrough();

const createBreakGlassAccessSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  target_resource_type: z.string().trim().min(1).max(120),
  target_resource_id: z.string().trim().max(64).optional().nullable(),
  reason: z.string().trim().min(1).max(255),
  justification_json: jsonObjectSchema.optional().nullable(),
  requested_scope_json: jsonObjectSchema.optional().nullable(),
  starts_at: z.string().datetime().optional().nullable(),
  expires_at: z.string().datetime().optional().nullable(),
  etag: z.string().trim().max(128).optional().nullable(),
});

const revokeBreakGlassAccessSchema = z.object({
  revoke_reason: z.string().trim().max(10000).optional().nullable(),
});

const breakGlassAccessIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listBreakGlassAccessesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  requested_by_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  target_resource_type: z.string().trim().optional(),
  status: z.enum(['REQUESTED', 'ACTIVE', 'REJECTED', 'EXPIRED', 'REVOKED']).optional(),
  review_status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'ESCALATED']).optional(),
});

module.exports = {
  breakGlassAccessIdParamsSchema,
  createBreakGlassAccessSchema,
  listBreakGlassAccessesQuerySchema,
  revokeBreakGlassAccessSchema,
};
