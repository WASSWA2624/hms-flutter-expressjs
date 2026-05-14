/**
 * Shift template validation schemas
 */
const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');

const timeStringSchema = z.string().regex(/^\d{1,2}:\d{2}(:\d{2})?$/, 'Time must be HH:mm or HH:mm:ss');

const createShiftTemplateSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().min(1).max(120),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']),
  default_start_time: timeStringSchema,
  default_end_time: timeStringSchema,
  duration_minutes: z.number().int().positive().optional().nullable(),
  is_active: z.boolean().default(true)
});

const updateShiftTemplateSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().min(1).max(120).optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
  default_start_time: timeStringSchema.optional(),
  default_end_time: timeStringSchema.optional(),
  duration_minutes: z.number().int().positive().optional().nullable(),
  is_active: z.boolean().optional()
});

const shiftTemplateIdParamsSchema = z.object({ id: uuidOrFriendlyIdentifierSchema });

const listShiftTemplatesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
  is_active: z.enum(['true', 'false']).optional()
});

module.exports = {
  createShiftTemplateSchema,
  updateShiftTemplateSchema,
  shiftTemplateIdParamsSchema,
  listShiftTemplatesQuerySchema
};
