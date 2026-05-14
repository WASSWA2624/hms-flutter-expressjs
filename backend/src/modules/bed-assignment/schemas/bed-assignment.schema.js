/**
 * Bed Assignment module validation schemas
 *
 * @module modules/bed-assignment/schemas
 * @description Zod validation schemas for bed assignment endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create bed assignment body validation
 * Used for POST /bed-assignments endpoint
 */
const createBedAssignmentSchema = z.object({
  admission_id: uuidSchema,
  bed_id: uuidSchema,
  assigned_at: isoDateSchema.optional()
});

/**
 * Update bed assignment body validation
 * Used for PUT /bed-assignments/:id endpoint
 * All fields optional for partial updates
 */
const updateBedAssignmentSchema = z.object({
  bed_id: uuidSchema.optional(),
  assigned_at: isoDateSchema.optional(),
  released_at: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * Bed Assignment ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const bedAssignmentIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List bed assignments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with bed assignment-specific filters
 */
const listBedAssignmentsQuerySchema = listQuerySchema.extend({
  admission_id: uuidSchema.optional(),
  bed_id: uuidSchema.optional()
});

module.exports = {
  createBedAssignmentSchema,
  updateBedAssignmentSchema,
  bedAssignmentIdParamsSchema,
  listBedAssignmentsQuerySchema
};
