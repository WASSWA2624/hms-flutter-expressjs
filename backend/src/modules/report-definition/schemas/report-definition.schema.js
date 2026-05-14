const { z } = require('zod');
const {
  listQuerySchema,
  nonNegativeIntSchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');
const {
  REPORT_DATASETS,
  REPORT_DEFINITION_STATUSES,
  REPORT_FORMATS,
} = require('@lib/reports/constants');

const reportDatasetKeys = REPORT_DATASETS.map((entry) => entry.key);

const reportDefinitionDslSchema = z.object({
  dataset_key: z.enum(reportDatasetKeys),
  columns: z.array(z.string().trim().min(1)).default([]),
  default_filters: z.union([z.array(z.any()), z.object({}).passthrough()]).optional().nullable(),
  group_by: z.array(z.string().trim().min(1)).optional().default([]),
  sort: z
    .array(
      z.object({
        field: z.string().trim().min(1),
        direction: z.enum(['asc', 'desc']).default('asc'),
      })
    )
    .optional()
    .default([]),
  visualization: z.string().trim().min(1).max(80).optional().nullable(),
});

const createReportDefinitionSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  description: z.string().trim().max(4000).optional().nullable(),
  dataset_key: z.enum(reportDatasetKeys),
  category: z.string().trim().min(1).max(80).optional(),
  status: z.enum(REPORT_DEFINITION_STATUSES).optional(),
  default_format: z.enum(REPORT_FORMATS).optional(),
  definition_json: reportDefinitionDslSchema,
  parameter_schema_json: z.object({}).passthrough().optional().nullable(),
});

const updateReportDefinitionSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  description: z.string().trim().max(4000).optional().nullable(),
  dataset_key: z.enum(reportDatasetKeys).optional(),
  category: z.string().trim().min(1).max(80).optional(),
  status: z.enum(REPORT_DEFINITION_STATUSES).optional(),
  default_format: z.enum(REPORT_FORMATS).optional(),
  definition_json: reportDefinitionDslSchema.optional(),
  parameter_schema_json: z.object({}).passthrough().optional().nullable(),
  version: z.coerce.number().int().positive().optional(),
});

const runReportDefinitionNowSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  format: z.enum(REPORT_FORMATS).optional(),
  parameters_json: z.object({}).passthrough().optional().nullable(),
  retention_days: nonNegativeIntSchema.optional(),
});

const reportDefinitionIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listReportDefinitionsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  created_by: uuidOrFriendlyIdentifierSchema.optional(),
  owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  dataset_key: z.enum(reportDatasetKeys).optional(),
  category: z.string().trim().optional(),
  status: z.enum(REPORT_DEFINITION_STATUSES).optional(),
  since: z.string().datetime().optional(),
});

module.exports = {
  createReportDefinitionSchema,
  listReportDefinitionsQuerySchema,
  reportDefinitionDslSchema,
  reportDefinitionIdParamsSchema,
  runReportDefinitionNowSchema,
  updateReportDefinitionSchema,
};
