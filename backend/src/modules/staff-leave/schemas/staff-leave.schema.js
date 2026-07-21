/**
 * Staff leave module validation schemas
 *
 * @module modules/staff-leave/schemas
 * @description Zod validation schemas for staff leave endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Leave status enum (matches Prisma schema)
 * Enum values: REQUESTED, APPROVED, REJECTED, CANCELLED
 */
const leaveStatusEnum = z.enum(['REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED']);

/**
 * Leave type enum (matches Prisma schema)
 */
const leaveTypeEnum = z.enum([
  'ANNUAL',
  'SICK',
  'MATERNITY',
  'PATERNITY',
  'COMPASSIONATE',
  'UNPAID',
  'STUDY',
  'EMERGENCY',
  'OTHER']);

/**
 * Half-day period enum (matches Prisma schema)
 */
const leaveHalfDayPeriodEnum = z.enum(['MORNING', 'AFTERNOON']);

const sameCalendarDay = (startDate, endDate) => {
  const start = new Date(startDate);
  const end = new Date(endDate);
  return (
    start.getUTCFullYear() === end.getUTCFullYear() &&
    start.getUTCMonth() === end.getUTCMonth() &&
    start.getUTCDate() === end.getUTCDate()
  );
};

const leaveDurationRefinement = (value, ctx) => {
  if (!value.is_half_day) {
    return;
  }
  if (!value.half_day_period) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'errors.staff_leave.half_day_period_required',
      path: ['half_day_period']});
  }
  if (!sameCalendarDay(value.start_date, value.end_date)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'errors.staff_leave.half_day_single_day_only',
      path: ['end_date']});
  }
};

// ==================== Body Schemas ====================

/**
 * Create staff leave body validation
 * Used for POST /staff-leaves endpoint
 */
const createStaffLeaveSchema = z
  .object({
    staff_profile_id: uuidOrFriendlyIdentifierSchema,
    leave_type: leaveTypeEnum,
    status: leaveStatusEnum,
    start_date: z.coerce.date(),
    end_date: z.coerce.date(),
    is_half_day: z.boolean().optional().default(false),
    half_day_period: leaveHalfDayPeriodEnum.optional().nullable(),
    reason: z.string().trim().optional().nullable(),
    handover_notes: z.string().trim().optional().nullable(),
    covering_staff_profile_id: uuidOrFriendlyIdentifierSchema.optional().nullable()})
  .superRefine(leaveDurationRefinement);

/**
 * Update staff leave body validation
 * Used for PUT /staff-leaves/:id endpoint
 * All fields optional for partial updates
 */
const updateStaffLeaveSchema = z
  .object({
    leave_type: leaveTypeEnum.optional(),
    status: leaveStatusEnum.optional(),
    start_date: z.coerce.date().optional(),
    end_date: z.coerce.date().optional(),
    is_half_day: z.boolean().optional(),
    half_day_period: leaveHalfDayPeriodEnum.optional().nullable(),
    reason: z.string().trim().optional().nullable(),
    handover_notes: z.string().trim().optional().nullable(),
    covering_staff_profile_id: uuidOrFriendlyIdentifierSchema.optional().nullable()})
  .superRefine((value, ctx) => {
    if (value.start_date == null || value.end_date == null) {
      return;
    }
    leaveDurationRefinement(
      {
        is_half_day: value.is_half_day === true,
        half_day_period: value.half_day_period,
        start_date: value.start_date,
        end_date: value.end_date},
      ctx
    );
  });

// ==================== URL Params ====================

/**
 * Staff leave ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const staffLeaveIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

// ==================== Query Params ====================

/**
 * List staff leaves query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with staff-leave-specific filters
 */
const listStaffLeavesQuerySchema = listQuerySchema.extend({
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: leaveStatusEnum.optional(),
  leave_type: leaveTypeEnum.optional()});

module.exports = {
  createStaffLeaveSchema,
  updateStaffLeaveSchema,
  staffLeaveIdParamsSchema,
  listStaffLeavesQuerySchema,
  leaveStatusEnum,
  leaveTypeEnum,
  leaveHalfDayPeriodEnum};
