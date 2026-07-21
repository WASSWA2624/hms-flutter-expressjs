/**
 * Shift template validation schemas
 */
const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');
const { slotsOverlap } = require('@modules/staff-availability/lib/availability-slots');

const timeStringSchema = z.string().regex(/^\d{1,2}:\d{2}(:\d{2})?$/, 'Time must be HH:mm or HH:mm:ss');

const weeklyScheduleSlotSchema = z.object({
  start_time: timeStringSchema,
  end_time: timeStringSchema}).refine((slot) => slot.end_time > slot.start_time, {
  message: 'End time must be after start time',
  path: ['end_time']});

const weeklyScheduleDaySchema = z.object({
  day_of_week: z.number().int().min(0).max(6),
  time_slots: z.array(weeklyScheduleSlotSchema).min(1)}).superRefine((data, ctx) => {
  if (slotsOverlap(data.time_slots)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Time slots on the same day must not overlap',
      path: ['time_slots']});
  }
});

const weeklyScheduleSchema = z.array(weeklyScheduleDaySchema).min(1).max(7).superRefine((days, ctx) => {
  const seenDays = new Set();
  days.forEach((day, index) => {
    if (seenDays.has(day.day_of_week)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Each day_of_week may only appear once',
        path: [index, 'day_of_week']});
      return;
    }
    seenDays.add(day.day_of_week);
  });
});

const createShiftTemplateSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().min(1).max(120),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']),
  default_start_time: timeStringSchema.optional(),
  default_end_time: timeStringSchema.optional(),
  weekly_schedule_json: weeklyScheduleSchema.optional(),
  duration_minutes: z.number().int().positive().optional().nullable(),
  is_active: z.boolean().default(true)}).superRefine((data, ctx) => {
  if (!data.weekly_schedule_json && (!data.default_start_time || !data.default_end_time)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'A weekly schedule or default start/end time is required',
      path: ['weekly_schedule_json']});
  }
});

const updateShiftTemplateSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().min(1).max(120).optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
  default_start_time: timeStringSchema.optional(),
  default_end_time: timeStringSchema.optional(),
  weekly_schedule_json: weeklyScheduleSchema.optional(),
  duration_minutes: z.number().int().positive().optional().nullable(),
  is_active: z.boolean().optional()}).superRefine((data, ctx) => {
  if (data.weekly_schedule_json) {
    return;
  }
  if (
    Object.prototype.hasOwnProperty.call(data, 'default_start_time') ||
    Object.prototype.hasOwnProperty.call(data, 'default_end_time')
  ) {
    if (!data.default_start_time || !data.default_end_time) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Both default start and end time are required',
        path: ['default_end_time']});
    }
  }
});

const shiftTemplateIdParamsSchema = z.object({ id: uuidOrFriendlyIdentifierSchema });

const listShiftTemplatesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
  is_active: z.enum(['true', 'false']).optional()});

module.exports = {
  createShiftTemplateSchema,
  updateShiftTemplateSchema,
  shiftTemplateIdParamsSchema,
  listShiftTemplatesQuerySchema};
