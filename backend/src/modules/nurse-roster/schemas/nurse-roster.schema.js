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

const constraintsSchema = z.object({
  max_shifts_per_nurse: z.number().int().positive().optional(),
  max_shifts_per_week: z.number().int().positive().optional(),
  max_hours_per_week: z.number().min(0).optional(),
  min_rest_hours: z.number().min(0).optional(),
  max_consecutive_working_days: z.number().int().positive().optional(),
  skill_matching: z.boolean().optional()
}).optional();

const createNurseRosterSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  period_start: isoDateSchema,
  period_end: isoDateSchema,
  status: z.enum(['DRAFT', 'PUBLISHED']).default('DRAFT'),
  constraints: constraintsSchema
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
  listNurseRostersQuerySchema
};
