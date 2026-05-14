/**
 * Roster day off validation schemas
 */
const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');
const dateStringSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD');

const createRosterDayOffSchema = z.object({
  nurse_roster_id: uuidOrFriendlyIdentifierSchema,
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  off_date: dateStringSchema,
  reason: z.string().max(255).optional().nullable()
});

const updateRosterDayOffSchema = z.object({
  off_date: dateStringSchema.optional(),
  reason: z.string().max(255).optional().nullable()
});

const rosterDayOffIdParamsSchema = z.object({ id: uuidOrFriendlyIdentifierSchema });

const listRosterDayOffsQuerySchema = listQuerySchema.extend({
  nurse_roster_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  off_date_from: dateStringSchema.optional(),
  off_date_to: dateStringSchema.optional()
});

module.exports = {
  createRosterDayOffSchema,
  updateRosterDayOffSchema,
  rosterDayOffIdParamsSchema,
  listRosterDayOffsQuerySchema
};
