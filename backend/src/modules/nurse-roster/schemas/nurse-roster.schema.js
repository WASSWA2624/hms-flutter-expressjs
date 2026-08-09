/**
 * Nurse roster module validation schemas
 *
 * @module modules/nurse-roster/schemas
 * @description Zod validation schemas for nurse roster endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

const weekdaySchema = z.enum(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']);

const constraintsSchema = z.object({
  max_shifts_per_nurse: z.number().int().positive().optional(),
  max_shifts_per_week: z.number().int().positive().optional(),
  max_hours_per_week: z.number().min(0).optional(),
  min_rest_hours: z.number().min(0).optional(),
  max_consecutive_working_days: z.number().int().positive().optional(),
  skill_matching: z.boolean().optional(),
  respect_public_holidays: z.boolean().optional(),
  public_holidays: z.array(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  working_days: z.array(weekdaySchema).optional(),
  default_start_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  default_end_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  attached_staff_ids: z.array(uuidOrFriendlyIdentifierSchema).optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
}).optional();

const createNurseRosterSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  is_recurring: z.boolean().default(false),
  period_start: isoDateSchema,
  period_end: isoDateSchema,
  status: z.enum(['DRAFT', 'PUBLISHED']).default('DRAFT'),
  constraints: constraintsSchema,
  materialize_shifts: z.boolean().default(true),
}).refine((data) => {
  const start = new Date(data.period_start);
  const end = new Date(data.period_end);
  return end > start;
}, {
  message: 'errors.validation.period_end_after_start',
  path: ['period_end']
});

const updateNurseRosterSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  is_recurring: z.boolean().optional(),
  period_start: isoDateSchema.optional(),
  period_end: isoDateSchema.optional(),
  status: z.enum(['DRAFT', 'PUBLISHED']).optional(),
  constraints: constraintsSchema
}).refine((data) => {
  if (data.period_start && data.period_end) {
    const start = new Date(data.period_start);
    const end = new Date(data.period_end);
    return end > start;
  }
  return true;
}, {
  message: 'errors.validation.period_end_after_start',
  path: ['period_end']
});

const publishNurseRosterSchema = z.object({
  notify_staff: z.boolean().default(true)
});

const generateNurseRosterSchema = z.object({
  period_start: isoDateSchema.optional(),
  period_end: isoDateSchema.optional(),
  constraints: constraintsSchema
}).refine((data) => {
  if (data.period_start && data.period_end) {
    const start = new Date(data.period_start);
    const end = new Date(data.period_end);
    return end > start;
  }
  return true;
}, {
  message: 'errors.validation.period_end_after_start',
  path: ['period_end']
});

const nurseRosterIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const rosterStaffParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
  staffProfileId: uuidOrFriendlyIdentifierSchema
});

const attachRosterStaffSchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema
});

const listNurseRostersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'PUBLISHED']).optional(),
  period_start_from: z.string().datetime().optional(),
  period_start_to: z.string().datetime().optional()
});

module.exports = {
  createNurseRosterSchema,
  updateNurseRosterSchema,
  publishNurseRosterSchema,
  generateNurseRosterSchema,
  nurseRosterIdParamsSchema,
  rosterStaffParamsSchema,
  attachRosterStaffSchema,
  listNurseRostersQuerySchema
};
