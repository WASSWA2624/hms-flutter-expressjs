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
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Leave status enum (matches Prisma schema)
 * Enum values: REQUESTED, APPROVED, REJECTED, CANCELLED
 */
const leaveStatusEnum = z.enum(['REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED']);

// ==================== Body Schemas ====================

/**
 * Create staff leave body validation
 * Used for POST /staff-leaves endpoint
 */
const createStaffLeaveSchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  status: leaveStatusEnum,
  start_date: z.coerce.date(),
  end_date: z.coerce.date(),
  reason: z.string().trim().optional().nullable()
});

/**
 * Update staff leave body validation
 * Used for PUT /staff-leaves/:id endpoint
 * All fields optional for partial updates
 */
const updateStaffLeaveSchema = z.object({
  status: leaveStatusEnum.optional(),
  start_date: z.coerce.date().optional(),
  end_date: z.coerce.date().optional(),
  reason: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Staff leave ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const staffLeaveIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List staff leaves query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with staff-leave-specific filters
 */
const listStaffLeavesQuerySchema = listQuerySchema.extend({
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: leaveStatusEnum.optional()
});

module.exports = {
  createStaffLeaveSchema,
  updateStaffLeaveSchema,
  staffLeaveIdParamsSchema,
  listStaffLeavesQuerySchema,
  leaveStatusEnum
};
