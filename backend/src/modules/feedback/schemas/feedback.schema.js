/**
 * Feedback module validation schemas
 */

const { z } = require('zod');

const submitNpsSchema = z.object({
  score: z.number().int().min(0).max(10),
  comment: z.string().trim().max(2000).optional().nullable(),
  campaign_id: z.string().trim().max(120).optional().nullable()
});

const submitCsatSchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().max(2000).optional().nullable(),
  campaign_id: z.string().trim().max(120).optional().nullable()
});

module.exports = {
  submitNpsSchema,
  submitCsatSchema
};
