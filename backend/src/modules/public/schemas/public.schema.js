/**
 * Public module validation schemas
 */

const { z } = require('zod');
const { listQuerySchema } = require('@lib/validation/zod');

const listPublicResourcesQuerySchema = listQuerySchema.extend({
  search: z.string().trim().optional()
});

module.exports = {
  listPublicResourcesQuerySchema
};
