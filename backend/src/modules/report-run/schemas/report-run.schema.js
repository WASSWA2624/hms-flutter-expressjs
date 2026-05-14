const { z } = require('zod');
const {
  listQuerySchema,
  nonNegativeIntSchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');
const {
  REPORT_FORMATS,
  REPORT_RUN_STATUSES,
  REPORT_TRIGGER_TYPES,
} = require('@lib/reports/constants');

const createReportRunSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  report_definition_id: uuidOrFriendlyIdentifierSchema,
  format: z.enum(REPORT_FORMATS).optional(),
  parameters_json: z.object({}).passthrough().optional().nullable(),
  retention_days: nonNegativeIntSchema.optional(),
});

const updateReportRunSchema = z.object({
  status: z.enum(REPORT_RUN_STATUSES).optional(),
  error_message: z.string().trim().max(10000).optional().nullable(),
  completed_at: z.string().datetime().optional().nullable(),
  expires_at: z.string().datetime().optional().nullable(),
  output_file_name: z.string().trim().max(255).optional().nullable(),
  version: z.coerce.number().int().positive().optional(),
});

const reportRunIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const reportRunMutationBodySchema = z.object({
  format: z.enum(REPORT_FORMATS).optional(),
  retention_days: nonNegativeIntSchema.optional(),
});

const listReportRunsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  report_definition_id: uuidOrFriendlyIdentifierSchema.optional(),
  schedule_id: uuidOrFriendlyIdentifierSchema.optional(),
  owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(REPORT_RUN_STATUSES).optional(),
  format: z.enum(REPORT_FORMATS).optional(),
  trigger_type: z.enum(REPORT_TRIGGER_TYPES).optional(),
  search: z.string().trim().optional(),
  since: z.string().datetime().optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

module.exports = {
  createReportRunSchema,
  listReportRunsQuerySchema,
  reportRunIdParamsSchema,
  reportRunMutationBodySchema,
  updateReportRunSchema,
};
