/**
 * Staff availability validation schemas
 */
const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema, isoDateSchema } = require('@lib/validation/zod');
const timeStringSchema = z.string().regex(/^\d{1,2}:\d{2}(:\d{2})?$/, 'Time must be HH:mm or HH:mm:ss');

const createStaffAvailabilitySchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  day_of_week: z.number().int().min(0).max(6),
  start_time: timeStringSchema,
  end_time: timeStringSchema,
  preference: z.enum(['PREFERRED', 'AVAILABLE', 'UNAVAILABLE']).default('AVAILABLE'),
  effective_from: isoDateSchema,
  effective_to: isoDateSchema.optional().nullable()
});

const updateStaffAvailabilitySchema = z.object({
  day_of_week: z.number().int().min(0).max(6).optional(),
  start_time: timeStringSchema.optional(),
  end_time: timeStringSchema.optional(),
  preference: z.enum(['PREFERRED', 'AVAILABLE', 'UNAVAILABLE']).optional(),
  effective_from: isoDateSchema.optional(),
  effective_to: isoDateSchema.optional().nullable()
});

const staffAvailabilityIdParamsSchema = z.object({ id: uuidOrFriendlyIdentifierSchema });

const listStaffAvailabilitiesQuerySchema = listQuerySchema.extend({
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  day_of_week: z.number().int().min(0).max(6).optional(),
  preference: z.enum(['PREFERRED', 'AVAILABLE', 'UNAVAILABLE']).optional()
});

module.exports = {
  createStaffAvailabilitySchema,
  updateStaffAvailabilitySchema,
  staffAvailabilityIdParamsSchema,
  listStaffAvailabilitiesQuerySchema
};
