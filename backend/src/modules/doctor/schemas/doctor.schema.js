/**
 * Doctor orchestration validation schemas
 *
 * @module modules/doctor/schemas
 */

const { z } = require('zod');
const { listQuerySchema, decimalStringSchema } = require('@lib/validation/zod');

const FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

const resourceFriendlyIdSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .regex(FRIENDLY_ID_REGEX, 'Invalid identifier format')
  .transform((value) => value.toUpperCase());

const resourceIdentifierSchema = resourceFriendlyIdSchema;

const practitionerTypeSchema = z.enum(['MO', 'SPECIALIST']);
const userStatusSchema = z.enum(['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING']);
const scheduleTypeSchema = z.enum(['RECURRING', 'OVERRIDE']);

const recurringScheduleSchema = z.object({
  day_of_week: z.number().int().min(0).max(6),
  start_time: z.string().trim().datetime(),
  end_time: z.string().trim().datetime(),
  timezone: z.string().trim().min(1).max(64).optional().default('UTC'),
  schedule_type: scheduleTypeSchema.optional().default('RECURRING'),
  effective_from: z.string().trim().datetime().optional().nullable(),
  effective_to: z.string().trim().datetime().optional().nullable(),
});

const scheduleOverrideSchema = z.object({
  schedule_index: z.number().int().min(0).optional(),
  override_date: z.string().trim().datetime(),
  start_time: z.string().trim().datetime(),
  end_time: z.string().trim().datetime(),
  is_available: z.boolean().optional().default(true),
});

const createDoctorSchema = z.object({
  tenant_id: resourceFriendlyIdSchema,
  facility_id: resourceFriendlyIdSchema.optional().nullable(),
  email: z.string().trim().email().max(255),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  password: z.string().trim().min(8).max(255).optional(),
  password_hash: z.string().trim().min(1).max(255).optional(),
  status: userStatusSchema.default('ACTIVE'),
  position_title: z.string().trim().min(1).max(120),
  practitioner_type: practitionerTypeSchema.default('MO'),
  position_id: resourceIdentifierSchema.optional(),
  position_name: z.string().trim().min(1).max(120).optional(),
  consultation_fee: decimalStringSchema.optional().nullable(),
  consultation_currency: z.string().trim().min(1).max(10).optional().nullable(),
  is_fee_overridden: z.boolean().optional(),
  role_ids: z.array(resourceIdentifierSchema).optional().default([]),
  recurring_schedules: z.array(recurringScheduleSchema).optional().default([]),
  schedule_overrides: z.array(scheduleOverrideSchema).optional().default([]),
});

const updateDoctorSchema = z.object({
  facility_id: resourceFriendlyIdSchema.optional().nullable(),
  email: z.string().trim().email().max(255).optional(),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  password: z.string().trim().min(8).max(255).optional(),
  password_hash: z.string().trim().min(1).max(255).optional(),
  status: userStatusSchema.optional(),
  position_title: z.string().trim().min(1).max(120).optional(),
  practitioner_type: practitionerTypeSchema.optional(),
  position_id: resourceIdentifierSchema.optional(),
  position_name: z.string().trim().min(1).max(120).optional(),
  consultation_fee: decimalStringSchema.optional().nullable(),
  consultation_currency: z.string().trim().min(1).max(10).optional().nullable(),
  is_fee_overridden: z.boolean().optional(),
  role_ids: z.array(resourceIdentifierSchema).optional(),
  recurring_schedules: z.array(recurringScheduleSchema).optional(),
  schedule_overrides: z.array(scheduleOverrideSchema).optional(),
});

const doctorIdParamsSchema = z.object({
  id: resourceFriendlyIdSchema,
});

const listDoctorsQuerySchema = listQuerySchema.extend({
  tenant_id: resourceFriendlyIdSchema.optional(),
  facility_id: resourceFriendlyIdSchema.optional(),
  practitioner_type: practitionerTypeSchema.optional(),
  position_title: z.string().trim().optional(),
  search: z.string().trim().optional(),
});

module.exports = {
  createDoctorSchema,
  updateDoctorSchema,
  doctorIdParamsSchema,
  listDoctorsQuerySchema,
};
