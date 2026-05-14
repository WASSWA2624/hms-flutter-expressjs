const { z } = require('zod');
const {
  listQuerySchema,
  nonNegativeIntSchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');
const {
  REPORT_FORMATS,
  REPORT_SCHEDULE_FREQUENCIES,
  REPORT_SCHEDULE_STATUSES,
} = require('@lib/reports/constants');

const createReportScheduleSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  report_definition_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  status: z.enum(REPORT_SCHEDULE_STATUSES).optional(),
  frequency: z.enum(REPORT_SCHEDULE_FREQUENCIES),
  time_of_day: z.string().regex(/^\d{2}:\d{2}$/).optional().nullable(),
  day_of_week: z.coerce.number().int().min(0).max(6).optional().nullable(),
  day_of_month: z.coerce.number().int().min(1).max(31).optional().nullable(),
  timezone: z.string().trim().min(2).max(80).optional(),
  format: z.enum(REPORT_FORMATS).optional(),
  parameter_overrides_json: z.object({}).passthrough().optional().nullable(),
  retention_days: nonNegativeIntSchema.optional(),
});

const updateReportScheduleSchema = createReportScheduleSchema.partial().extend({
  version: z.coerce.number().int().positive().optional(),
});

const reportScheduleIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listReportSchedulesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  report_definition_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(REPORT_SCHEDULE_STATUSES).optional(),
  frequency: z.enum(REPORT_SCHEDULE_FREQUENCIES).optional(),
  search: z.string().trim().optional(),
  since: z.string().datetime().optional(),
});

module.exports = {
  createReportScheduleSchema,
  listReportSchedulesQuerySchema,
  reportScheduleIdParamsSchema,
  updateReportScheduleSchema,
};
