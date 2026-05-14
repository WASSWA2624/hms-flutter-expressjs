const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const createBreakGlassReviewSchema = z.object({
  break_glass_access_id: uuidOrFriendlyIdentifierSchema,
  status: z.enum(['APPROVED', 'REJECTED', 'ESCALATED']),
  notes: z.string().trim().max(10000).optional().nullable(),
  expires_at: z.string().datetime().optional().nullable(),
});

const breakGlassReviewIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listBreakGlassReviewsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  break_glass_access_id: uuidOrFriendlyIdentifierSchema.optional(),
  reviewer_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['APPROVED', 'REJECTED', 'ESCALATED']).optional(),
});

module.exports = {
  breakGlassReviewIdParamsSchema,
  createBreakGlassReviewSchema,
  listBreakGlassReviewsQuerySchema,
};
