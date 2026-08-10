/**
 * Roster module validation schemas
 *
 * @module modules/roster/schemas
 * @description Zod validation schemas for roster endpoints.
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

const timeSlotSchema = z.object({
  start_time: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/),
  end_time: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/),
});

const weeklyScheduleDaySchema = z.object({
  day_of_week: z.number().int().min(0).max(6),
  time_slots: z.array(timeSlotSchema).min(1),
});

const staffMetaSchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  staff_category: z
    .enum(['FULL_TIME', 'PART_TIME', 'LOCUM', 'SPECIALIST', 'CONTRACT', 'OTHER'])
    .optional()
    .nullable(),
  inactive: z.boolean().optional(),
});

const constraintsSchema = z.object({
  max_shifts_per_nurse: z.number().int().positive().optional(),
  max_shifts_per_week: z.number().int().positive().optional(),
  max_hours_per_week: z.number().min(0).optional(),
  min_rest_hours: z.number().min(0).optional(),
  max_consecutive_working_days: z.number().int().positive().optional(),
  skill_matching: z.boolean().optional(),
  respect_public_holidays: z.boolean().optional(),
  respect_weekends: z.boolean().optional(),
  public_holidays: z.array(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  working_days: z.array(weekdaySchema).optional(),
  month_days: z.array(z.number().int().min(1).max(31)).optional(),
  default_start_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  default_end_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  weekly_schedule_json: z.array(weeklyScheduleDaySchema).optional(),
  attached_staff_ids: z.array(uuidOrFriendlyIdentifierSchema).optional(),
  attached_staff_meta: z.array(staffMetaSchema).optional(),
  template_inactive: z.boolean().optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
}).optional();

const optionalBooleanSchema = z.boolean().optional();

const createRosterSchema = z.object({
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
  confirm_similar: optionalBooleanSchema,
}).refine((data) => {
  const start = new Date(data.period_start);
  const end = new Date(data.period_end);
  return end > start;
}, {
  message: 'errors.validation.period_end_after_start',
  path: ['period_end']
});

const updateRosterSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  is_recurring: z.boolean().optional(),
  period_start: isoDateSchema.optional(),
  period_end: isoDateSchema.optional(),
  status: z.enum(['DRAFT', 'PUBLISHED']).optional(),
  constraints: constraintsSchema,
  materialize_shifts: z.boolean().optional(),
  confirm_similar: optionalBooleanSchema,
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

const publishRosterSchema = z.object({
  notify_staff: z.boolean().default(true)
});

const generateRosterSchema = z.object({
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

const rosterIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const rosterStaffParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
  staffProfileId: uuidOrFriendlyIdentifierSchema
});

const attachRosterStaffSchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  staff_category: z
    .enum(['FULL_TIME', 'PART_TIME', 'LOCUM', 'SPECIALIST', 'CONTRACT', 'OTHER'])
    .optional(),
});

const listRostersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'PUBLISHED']).optional(),
  period_start_from: z.string().datetime().optional(),
  period_start_to: z.string().datetime().optional()
});

module.exports = {
  createRosterSchema,
  updateRosterSchema,
  publishRosterSchema,
  generateRosterSchema,
  rosterIdParamsSchema,
  rosterStaffParamsSchema,
  attachRosterStaffSchema,
  listRostersQuerySchema
};
