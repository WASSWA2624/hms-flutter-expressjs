const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');
const { REPORT_WIDGET_TYPES } = require('@lib/reports/constants');

const createDashboardWidgetSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  report_definition_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  widget_type: z.enum(REPORT_WIDGET_TYPES),
  role_scope_json: z.object({}).passthrough().optional().nullable(),
  placement: z.string().trim().max(120).optional().nullable(),
  sort_order: z.coerce.number().int().min(0).optional(),
  is_pinned: z.boolean().optional(),
  config_json: z.object({}).passthrough(),
});

const updateDashboardWidgetSchema = z.object({
  report_definition_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  widget_type: z.enum(REPORT_WIDGET_TYPES).optional(),
  role_scope_json: z.object({}).passthrough().optional().nullable(),
  placement: z.string().trim().max(120).optional().nullable(),
  sort_order: z.coerce.number().int().min(0).optional(),
  is_pinned: z.boolean().optional(),
  config_json: z.object({}).passthrough().optional(),
  version: z.coerce.number().int().positive().optional(),
});

const dashboardWidgetIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listDashboardWidgetsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  report_definition_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  search: z.string().trim().optional(),
  placement: z.string().trim().optional(),
  widget_type: z.enum(REPORT_WIDGET_TYPES).optional(),
  is_pinned: z.coerce.boolean().optional(),
  since: z.string().datetime().optional(),
});

const dashboardSummaryQuerySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  days: z.coerce.number().int().min(1).max(30).default(7),
});

module.exports = {
  createDashboardWidgetSchema,
  dashboardSummaryQuerySchema,
  dashboardWidgetIdParamsSchema,
  listDashboardWidgetsQuerySchema,
  updateDashboardWidgetSchema,
};
