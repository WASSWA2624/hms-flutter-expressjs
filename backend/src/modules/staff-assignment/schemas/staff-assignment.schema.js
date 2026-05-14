/**
 * Staff assignment module validation schemas
 *
 * @module modules/staff-assignment/schemas
 * @description Zod validation schemas for staff assignment endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create staff assignment body validation
 * Used for POST /staff-assignments endpoint
 */
const createStaffAssignmentSchema = z.object({
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  unit_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  start_date: z.coerce.date(),
  end_date: z.coerce.date().optional().nullable()
});

/**
 * Update staff assignment body validation
 * Used for PUT /staff-assignments/:id endpoint
 * All fields optional for partial updates
 */
const updateStaffAssignmentSchema = z.object({
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  unit_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  start_date: z.coerce.date().optional(),
  end_date: z.coerce.date().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Staff assignment ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const staffAssignmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List staff assignments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with staff-assignment-specific filters
 */
const listStaffAssignmentsQuerySchema = listQuerySchema.extend({
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  unit_id: uuidOrFriendlyIdentifierSchema.optional()
});

module.exports = {
  createStaffAssignmentSchema,
  updateStaffAssignmentSchema,
  staffAssignmentIdParamsSchema,
  listStaffAssignmentsQuerySchema
};
