const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const housekeepingPanelSchema = z.enum(['overview', 'tasks', 'requests', 'assets', 'history']);

const housekeepingResourceSchema = z.enum([
  'housekeeping-tasks',
  'housekeeping-schedules',
  'maintenance-requests',
  'assets',
  'asset-service-logs',
]);

const housekeepingQueueSchema = z.enum([
  'TODAY',
  'OVERDUE_TASKS',
  'OPEN_REQUESTS',
  'OVERDUE_REQUESTS',
  'SERVICE_HISTORY',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: housekeepingPanelSchema.optional(),
  resource: housekeepingResourceSchema.optional(),
  queue: housekeepingQueueSchema.optional(),
  search: z.string().trim().optional(),
  status: z.string().trim().min(1).max(80).optional(),
  priority: z.string().trim().min(1).max(80).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  room_id: uuidOrFriendlyIdentifierSchema.optional(),
  assignee_id: uuidOrFriendlyIdentifierSchema.optional(),
  date_preset: z.enum(['today', 'next_7_days', 'overdue', 'this_month']).optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  action: z.enum(['view', 'create', 'edit', 'complete', 'triage']).optional(),
});

const lookupsQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

module.exports = {
  housekeepingPanelSchema,
  housekeepingResourceSchema,
  housekeepingQueueSchema,
  workspaceQuerySchema,
  lookupsQuerySchema,
};
