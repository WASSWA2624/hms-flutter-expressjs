const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');
const { KPI_THRESHOLD_STATES } = require('@lib/reports/constants');

const createKpiSnapshotSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  metric_key: z.string().trim().min(1).max(80),
  metric_group: z.string().trim().min(1).max(80),
  value: z.union([z.coerce.number(), z.string().trim().min(1)]),
  threshold_state: z.enum(KPI_THRESHOLD_STATES),
  recorded_at: z.string().datetime().optional(),
});

const updateKpiSnapshotSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  metric_key: z.string().trim().min(1).max(80).optional(),
  metric_group: z.string().trim().min(1).max(80).optional(),
  value: z.union([z.coerce.number(), z.string().trim().min(1)]).optional(),
  threshold_state: z.enum(KPI_THRESHOLD_STATES).optional(),
  recorded_at: z.string().datetime().optional().nullable(),
  version: z.coerce.number().int().positive().optional(),
});

const kpiSnapshotIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listKpiSnapshotsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  metric_key: z.string().trim().optional(),
  metric_group: z.string().trim().optional(),
  threshold_state: z.enum(KPI_THRESHOLD_STATES).optional(),
  search: z.string().trim().optional(),
  since: z.string().datetime().optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

module.exports = {
  createKpiSnapshotSchema,
  kpiSnapshotIdParamsSchema,
  listKpiSnapshotsQuerySchema,
  updateKpiSnapshotSchema,
};
