/**
 * Shift swap request module validation schemas
 *
 * @module modules/shift-swap-request/schemas
 * @description Zod validation schemas for shift swap request endpoints.
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
 * Create shift swap request body validation
 * Used for POST /shift-swap-requests endpoint
 */
const createShiftSwapRequestSchema = z.object({
  shift_id: uuidOrFriendlyIdentifierSchema,
  requester_staff_id: uuidOrFriendlyIdentifierSchema,
  target_staff_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).default('SCHEDULED')
});

/**
 * Update shift swap request body validation
 * Used for PUT /shift-swap-requests/:id endpoint
 * All fields optional for partial updates
 */
const updateShiftSwapRequestSchema = z.object({
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  requester_staff_id: uuidOrFriendlyIdentifierSchema.optional(),
  target_staff_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).optional()
});

// ==================== URL Params ====================

/**
 * Shift swap request ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const shiftSwapRequestIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List shift swap requests query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with shift swap request-specific filters
 */
const listShiftSwapRequestsQuerySchema = listQuerySchema.extend({
  shift_id: uuidOrFriendlyIdentifierSchema.optional(),
  requester_staff_id: uuidOrFriendlyIdentifierSchema.optional(),
  target_staff_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).optional()
});

module.exports = {
  createShiftSwapRequestSchema,
  updateShiftSwapRequestSchema,
  shiftSwapRequestIdParamsSchema,
  listShiftSwapRequestsQuerySchema
};
