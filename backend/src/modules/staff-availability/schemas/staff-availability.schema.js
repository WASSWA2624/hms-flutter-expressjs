/**
 * Staff availability validation schemas
 */
const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema, isoDateSchema } = require('@lib/validation/zod');
const timeStringSchema = z.string().regex(/^\d{1,2}:\d{2}(:\d{2})?$/, 'Time must be HH:mm or HH:mm:ss');
const availabilityStatusEnum = z.enum(['PREFERRED', 'AVAILABLE', 'UNAVAILABLE']);
const availabilitySlotSchema = z.object({
  start_time: timeStringSchema,
  end_time: timeStringSchema,
}).refine((slot) => slot.end_time > slot.start_time, {
  message: 'End time must be after start time',
  path: ['end_time'],
});

const createStaffAvailabilitySchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  day_of_week: z.number().int().min(0).max(6),
  start_time: timeStringSchema.optional(),
  end_time: timeStringSchema.optional(),
  time_slots: z.array(availabilitySlotSchema).min(1).optional(),
  preference: availabilityStatusEnum.default('AVAILABLE'),
  status: availabilityStatusEnum.optional(),
  effective_from: isoDateSchema,
  effective_to: isoDateSchema.optional().nullable()
}).superRefine((data, ctx) => {
  if (!data.time_slots && (!data.start_time || !data.end_time)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'A time slot or start/end time is required',
      path: ['time_slots'],
    });
  }
});

const updateStaffAvailabilitySchema = z.object({
  day_of_week: z.number().int().min(0).max(6).optional(),
  start_time: timeStringSchema.optional(),
  end_time: timeStringSchema.optional(),
  time_slots: z.array(availabilitySlotSchema).min(1).optional(),
  preference: availabilityStatusEnum.optional(),
  status: availabilityStatusEnum.optional(),
  effective_from: isoDateSchema.optional(),
  effective_to: isoDateSchema.optional().nullable()
});

const staffAvailabilityIdParamsSchema = z.object({ id: uuidOrFriendlyIdentifierSchema });

const listStaffAvailabilitiesQuerySchema = listQuerySchema.extend({
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  day_of_week: z.number().int().min(0).max(6).optional(),
  preference: availabilityStatusEnum.optional(),
  status: availabilityStatusEnum.optional()
});

module.exports = {
  createStaffAvailabilitySchema,
  updateStaffAvailabilitySchema,
  staffAvailabilityIdParamsSchema,
  listStaffAvailabilitiesQuerySchema
};
