/**
 * Campaign module validation schemas
 */

const { z } = require('zod');
const { listQuerySchema } = require('@lib/validation/zod');

const campaignIdParamsSchema = z.object({
  id: z.string().trim().min(1).max(120)
});

const listCampaignsQuerySchema = listQuerySchema.extend({
  search: z.string().trim().optional()
});

module.exports = {
  campaignIdParamsSchema,
  listCampaignsQuerySchema
};
