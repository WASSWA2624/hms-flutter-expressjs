const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const biomedicalPanelSchema = z.enum([
  'overview',
  'registry',
  'preventive',
  'work-orders',
  'compliance',
  'support',
  'analytics',
]);

const biomedicalResourceSchema = z.enum([
  'equipment-registries',
  'equipment-maintenance-plans',
  'equipment-work-orders',
  'equipment-calibration-logs',
  'equipment-safety-test-logs',
  'equipment-downtime-logs',
  'equipment-incident-reports',
  'equipment-recall-notices',
  'equipment-service-providers',
  'equipment-warranty-contracts',
  'equipment-spare-parts',
  'equipment-categories',
  'equipment-disposal-transfers',
  'equipment-utilization-snapshots',
  'equipment-location-histories',
]);

const biomedicalQueueSchema = z.enum([
  'OVERDUE_PM',
  'OPEN_WORK_ORDERS',
  'CRITICAL_DOWNTIME',
  'RECALL_ACTIONS',
  'RETURN_TO_SERVICE',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: biomedicalPanelSchema.optional(),
  resource: biomedicalResourceSchema.optional(),
  queue: biomedicalQueueSchema.optional(),
  search: z.string().trim().optional(),
  status: z.string().trim().min(1).max(80).optional(),
  priority: z.string().trim().min(1).max(80).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  equipment_id: uuidOrFriendlyIdentifierSchema.optional(),
  engineer_id: uuidOrFriendlyIdentifierSchema.optional(),
  date_preset: z.enum(['today', 'next_7_days', 'overdue', 'this_month']).optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  action: z.enum(['view', 'create', 'edit', 'triage', 'start', 'return-to-service', 'log-evidence']).optional(),
});

const lookupsQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const faultReportSchema = z.object({
  equipment_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reported_equipment_name: z.string().trim().min(2).max(255).optional().nullable(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  source_scope: z.string().trim().min(2).max(80),
  source_route: z.string().trim().min(1).max(255),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
  priority: z.enum(['LOW', 'NORMAL', 'HIGH', 'CRITICAL']).optional().default('NORMAL'),
  symptoms: z.string().trim().max(4000).optional().default(''),
  patient_safety_risk: z.coerce.boolean().optional().default(false),
  description: z.string().trim().max(10000).optional().default(''),
  evidence_manifest: z.array(z.object({}).passthrough()).optional().default([]),
  context: z.object({}).passthrough().optional().default({}),
}).superRefine((value, context) => {
  const hasEquipmentId = Boolean(String(value.equipment_id || '').trim());
  const hasReportedEquipmentName = Boolean(
    String(value.reported_equipment_name || '').trim()
  );

  if (!hasEquipmentId && !hasReportedEquipmentName) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Equipment selection or a temporary equipment name is required',
      path: ['equipment_id'],
    });
  }
});

module.exports = {
  biomedicalPanelSchema,
  biomedicalResourceSchema,
  biomedicalQueueSchema,
  workspaceQuerySchema,
  lookupsQuerySchema,
  faultReportSchema,
};
