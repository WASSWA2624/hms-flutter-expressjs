/**
 * Lab QC log module validation schemas
 */

const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');

const createLabQcLogSchema = z.object({
  lab_test_id: uuidOrFriendlyIdentifierSchema,
  status: z.string().trim().max(80).optional().nullable(),
  notes: z.string().optional().nullable(),
  logged_at: z.string().datetime().optional()
});

const updateLabQcLogSchema = z.object({
  status: z.string().trim().max(80).optional().nullable(),
  notes: z.string().optional().nullable(),
  logged_at: z.string().datetime().optional()
});

const labQcLogIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const listLabQcLogsQuerySchema = listQuerySchema.extend({
  lab_test_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createLabQcLogSchema,
  updateLabQcLogSchema,
  labQcLogIdParamsSchema,
  listLabQcLogsQuerySchema
};
