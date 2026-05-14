const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema, dateStringSchema } = require('@lib/validation/zod');

const workspacePanelSchema = z.enum([
  'overview',
  'arrivals',
  'queue',
  'opd',
  'reminders',
  'capacity',
  'followups',
]);

const workspaceQueueSchema = z.enum([
  'ARRIVING_TODAY',
  'WAITING_QUEUE',
  'ACTIVE_OPD',
  'OVERDUE_REMINDERS',
  'FOLLOW_UPS_DUE',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: workspacePanelSchema.optional(),
  queue: workspaceQueueSchema.optional(),
  date: dateStringSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  provider_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.string().trim().min(1).max(80).optional(),
  search: z.string().trim().max(120).optional(),
});

const referenceDataQuerySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(120).optional(),
});

const resolveLegacyParamsSchema = z.object({
  resource: z.enum([
    'appointments',
    'appointment-reminders',
    'provider-schedules',
    'availability-slots',
    'visit-queues',
    'opd-flows',
    'follow-ups',
  ]),
  id: uuidOrFriendlyIdentifierSchema,
});

module.exports = {
  workspacePanelSchema,
  workspaceQueueSchema,
  workspaceQuerySchema,
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
};
