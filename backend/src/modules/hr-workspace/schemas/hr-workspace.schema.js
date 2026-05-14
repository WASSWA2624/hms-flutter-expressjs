const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const hrQueueSchema = z.enum([
  'LEAVE_REQUESTS',
  'SWAP_REQUESTS',
  'ROSTER_DRAFTS',
  'UNASSIGNED_SHIFTS',
  'PAYROLL_DRAFTS',
  'OVERDUE_SHIFTS',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: z
    .enum(['overview', 'staffing', 'roster', 'shifts', 'payroll', 'onboarding'])
    .optional(),
  resource: z
    .enum([
      'staff-positions',
      'staff-profiles',
      'staff-assignments',
      'staff-leaves',
      'staff-availabilities',
      'nurse-rosters',
      'roster-day-offs',
      'shifts',
      'shift-assignments',
      'shift-swap-requests',
      'shift-templates',
      'payroll-runs',
      'payroll-items',
      'doctors',
    ])
    .optional(),
  status: z.string().trim().min(1).max(80).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  roster_id: uuidOrFriendlyIdentifierSchema.optional(),
  payroll_run_id: uuidOrFriendlyIdentifierSchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  date_from: z.string().datetime().optional(),
  date_to: z.string().datetime().optional(),
  search: z.string().trim().optional(),
});

const workItemsQuerySchema = workspaceQuerySchema.extend({
  queue: hrQueueSchema.optional(),
});

const referenceDataQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const rosterIdentifierParamsSchema = z.object({
  rosterIdentifier: uuidOrFriendlyIdentifierSchema,
});

const shiftIdentifierParamsSchema = z.object({
  shiftIdentifier: uuidOrFriendlyIdentifierSchema,
});

const swapIdentifierParamsSchema = z.object({
  swapIdentifier: uuidOrFriendlyIdentifierSchema,
});

const leaveIdentifierParamsSchema = z.object({
  leaveIdentifier: uuidOrFriendlyIdentifierSchema,
});

const payrollRunIdentifierParamsSchema = z.object({
  payrollRunIdentifier: uuidOrFriendlyIdentifierSchema,
});

const resolveLegacyParamsSchema = z.object({
  resource: z.enum([
    'staff-positions',
    'staff-profiles',
    'staff-assignments',
    'staff-leaves',
    'shifts',
    'shift-assignments',
    'shift-swap-requests',
    'nurse-rosters',
    'shift-templates',
    'roster-day-offs',
    'staff-availabilities',
    'payroll-runs',
    'payroll-items',
    'doctors',
  ]),
  id: uuidOrFriendlyIdentifierSchema,
});

const rosterGenerateSchema = z.object({
  constraints: z
    .object({
      max_shifts_per_nurse: z.coerce.number().int().positive().optional(),
      max_shifts_per_week: z.coerce.number().int().positive().optional(),
      max_hours_per_week: z.coerce.number().positive().optional(),
      min_rest_hours: z.coerce.number().nonnegative().optional(),
      max_consecutive_working_days: z.coerce.number().int().positive().optional(),
      skill_matching: z.coerce.boolean().optional(),
    })
    .optional(),
  replace_existing_assignments: z.coerce.boolean().optional().default(true),
  dry_run: z.coerce.boolean().optional().default(false),
});

const rosterPublishSchema = z.object({
  notify_staff: z.coerce.boolean().optional().default(true),
  allow_partial_publish: z.coerce.boolean().optional().default(false),
  publish_note: z.string().trim().min(2).max(255).optional().nullable(),
});

const shiftOverrideSchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  reason: z.string().trim().min(2).max(255),
});

const swapApproveSchema = z.object({
  reason: z.string().trim().max(255).optional().nullable(),
});

const swapRejectSchema = z.object({
  reason: z.string().trim().min(2).max(255),
});

const leaveApproveSchema = z.object({
  reason: z.string().trim().max(255).optional().nullable(),
});

const leaveRejectSchema = z.object({
  reason: z.string().trim().min(2).max(255),
});

const payrollPreviewQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
});

const payrollProcessSchema = z.object({
  replace_existing_items: z.coerce.boolean().optional().default(false),
  notes: z.string().trim().max(255).optional().nullable(),
});

module.exports = {
  hrQueueSchema,
  workspaceQuerySchema,
  workItemsQuerySchema,
  referenceDataQuerySchema,
  rosterIdentifierParamsSchema,
  shiftIdentifierParamsSchema,
  swapIdentifierParamsSchema,
  leaveIdentifierParamsSchema,
  payrollRunIdentifierParamsSchema,
  resolveLegacyParamsSchema,
  rosterGenerateSchema,
  rosterPublishSchema,
  shiftOverrideSchema,
  swapApproveSchema,
  swapRejectSchema,
  leaveApproveSchema,
  leaveRejectSchema,
  payrollPreviewQuerySchema,
  payrollProcessSchema,
};
