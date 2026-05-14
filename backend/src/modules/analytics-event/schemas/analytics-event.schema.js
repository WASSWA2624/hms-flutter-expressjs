const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');
const { ANALYTICS_EVENT_SEVERITIES } = require('@lib/reports/constants');

const createAnalyticsEventSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  event_name: z.string().trim().min(1).max(255),
  event_category: z.string().trim().min(1).max(80),
  entity_type: z.string().trim().max(80).optional().nullable(),
  entity_public_id: z.string().trim().max(64).optional().nullable(),
  severity: z.enum(ANALYTICS_EVENT_SEVERITIES),
  payload_json: z.object({}).passthrough().optional().nullable(),
  occurred_at: z.string().datetime().optional(),
});

const updateAnalyticsEventSchema = z.object({
  user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  event_name: z.string().trim().min(1).max(255).optional(),
  event_category: z.string().trim().min(1).max(80).optional(),
  entity_type: z.string().trim().max(80).optional().nullable(),
  entity_public_id: z.string().trim().max(64).optional().nullable(),
  severity: z.enum(ANALYTICS_EVENT_SEVERITIES).optional(),
  payload_json: z.object({}).passthrough().optional().nullable(),
  occurred_at: z.string().datetime().optional().nullable(),
  version: z.coerce.number().int().positive().optional(),
});

const analyticsEventIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listAnalyticsEventsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  event_category: z.string().trim().optional(),
  entity_type: z.string().trim().optional(),
  severity: z.enum(ANALYTICS_EVENT_SEVERITIES).optional(),
  search: z.string().trim().optional(),
  since: z.string().datetime().optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

module.exports = {
  analyticsEventIdParamsSchema,
  createAnalyticsEventSchema,
  listAnalyticsEventsQuerySchema,
  updateAnalyticsEventSchema,
};
