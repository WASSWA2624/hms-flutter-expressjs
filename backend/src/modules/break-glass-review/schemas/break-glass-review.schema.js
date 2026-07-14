const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const MAX_BREAK_GLASS_TTL_MS = 24 * 60 * 60 * 1000;

const createBreakGlassReviewSchema = z
  .object({
    break_glass_access_id: uuidOrFriendlyIdentifierSchema,
    status: z.enum(['APPROVED', 'REJECTED', 'ESCALATED']),
    notes: z.string().trim().max(10000).optional().nullable(),
    expires_at: z.string().datetime().optional().nullable(),
  })
  .superRefine((value, ctx) => {
    if (value.status !== 'APPROVED') {
      return;
    }

    if (!value.expires_at) {
      // Service also accepts access.expires_at; schema allows omit when request already set it.
      return;
    }

    const expiresAt = new Date(value.expires_at);
    if (Number.isNaN(expiresAt.getTime())) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['expires_at'],
        message: 'expires_at must be a valid datetime',
      });
      return;
    }

    const now = Date.now();
    if (expiresAt.getTime() <= now) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['expires_at'],
        message: 'expires_at must be in the future',
      });
      return;
    }

    if (expiresAt.getTime() - now > MAX_BREAK_GLASS_TTL_MS) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['expires_at'],
        message: 'expires_at must be within 24 hours',
      });
    }
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
