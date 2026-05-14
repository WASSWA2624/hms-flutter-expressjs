/**
 * Shift assignment module validation schemas
 *
 * @module modules/shift-assignment/schemas
 * @description Zod validation schemas for shift assignment endpoints.
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
 * Create shift assignment body validation
 * Used for POST /shift-assignments endpoint
 */
const createShiftAssignmentSchema = z.object({
  shift_id: uuidOrFriendlyIdentifierSchema,
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  assigned_at: z.string().datetime().optional()
});

/**
 * Update shift assignment body validation
 * Used for PUT /shift-assignments/:id endpoint
 * All fields optional for partial updates
 */
const updateShiftAssignmentSchema = z.object({
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  assigned_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Shift assignment ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const shiftAssignmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List shift assignments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with shift assignment-specific filters
 */
const listShiftAssignmentsQuerySchema = listQuerySchema.extend({
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  assigned_at_from: z.string().datetime().optional(),
  assigned_at_to: z.string().datetime().optional()
});

module.exports = {
  createShiftAssignmentSchema,
  updateShiftAssignmentSchema,
  shiftAssignmentIdParamsSchema,
  listShiftAssignmentsQuerySchema
};
