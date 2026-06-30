/**
 * Staff availability validation schemas
 */
const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema, isoDateSchema } = require('@lib/validation/zod');
const { slotsOverlap } = require('../lib/availability-slots');

const timeStringSchema = z.string().regex(/^\d{1,2}:\d{2}(:\d{2})?$/, 'Time must be HH:mm or HH:mm:ss');
const availabilityStatusEnum = z.enum(['PREFERRED', 'AVAILABLE', 'UNAVAILABLE']);

const availabilitySlotSchema = z.object({
  start_time: timeStringSchema,
  end_time: timeStringSchema,
}).refine((slot) => slot.end_time > slot.start_time, {
  message: 'End time must be after start time',
  path: ['end_time'],
});

const validateNonOverlappingSlots = (timeSlots, ctx, pathPrefix = 'time_slots') => {
  if (!Array.isArray(timeSlots) || timeSlots.length < 2) {
    return;
  }

  if (slotsOverlap(timeSlots)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Time slots on the same day must not overlap',
      path: [pathPrefix],
    });
  }
};

const createStaffAvailabilitySchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  day_of_week: z.number().int().min(0).max(6),
  start_time: timeStringSchema.optional(),
  end_time: timeStringSchema.optional(),
  time_slots: z.array(availabilitySlotSchema).min(1).optional(),
  preference: availabilityStatusEnum.default('AVAILABLE'),
  status: availabilityStatusEnum.optional(),
  effective_from: isoDateSchema,
  effective_to: isoDateSchema.optional().nullable(),
}).superRefine((data, ctx) => {
  if (!data.time_slots && (!data.start_time || !data.end_time)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'A time slot or start/end time is required',
      path: ['time_slots'],
    });
  }

  if (data.time_slots) {
    validateNonOverlappingSlots(data.time_slots, ctx);
  }
});

const batchAvailabilityDaySchema = z.object({
  day_of_week: z.number().int().min(0).max(6),
  time_slots: z.array(availabilitySlotSchema).min(1),
}).superRefine((data, ctx) => {
  validateNonOverlappingSlots(data.time_slots, ctx);
});

const batchCreateStaffAvailabilitySchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  preference: availabilityStatusEnum.default('AVAILABLE'),
  status: availabilityStatusEnum.optional(),
  effective_from: isoDateSchema,
  effective_to: isoDateSchema.optional().nullable(),
  days: z.array(batchAvailabilityDaySchema).min(1).max(7),
}).superRefine((data, ctx) => {
  const seenDays = new Set();
  data.days.forEach((day, index) => {
    if (seenDays.has(day.day_of_week)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Each day_of_week may only appear once in a batch',
        path: ['days', index, 'day_of_week'],
      });
      return;
    }
    seenDays.add(day.day_of_week);
  });
});

const updateStaffAvailabilitySchema = z.object({
  day_of_week: z.number().int().min(0).max(6).optional(),
  start_time: timeStringSchema.optional(),
  end_time: timeStringSchema.optional(),
  time_slots: z.array(availabilitySlotSchema).min(1).optional(),
  preference: availabilityStatusEnum.optional(),
  status: availabilityStatusEnum.optional(),
  effective_from: isoDateSchema.optional(),
  effective_to: isoDateSchema.optional().nullable(),
}).superRefine((data, ctx) => {
  if (data.time_slots) {
    validateNonOverlappingSlots(data.time_slots, ctx);
  }
});

const staffAvailabilityIdParamsSchema = z.object({ id: uuidOrFriendlyIdentifierSchema });

const listStaffAvailabilitiesQuerySchema = listQuerySchema.extend({
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  day_of_week: z.coerce.number().int().min(0).max(6).optional(),
  preference: availabilityStatusEnum.optional(),
  status: availabilityStatusEnum.optional(),
});

module.exports = {
  createStaffAvailabilitySchema,
  batchCreateStaffAvailabilitySchema,
  updateStaffAvailabilitySchema,
  staffAvailabilityIdParamsSchema,
  listStaffAvailabilitiesQuerySchema,
};
