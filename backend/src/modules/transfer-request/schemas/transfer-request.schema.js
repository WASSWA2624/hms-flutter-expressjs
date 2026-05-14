/**
 * Transfer request module validation schemas
 *
 * @module modules/transfer-request/schemas
 * @description Zod validation schemas for transfer request endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create transfer request body validation
 * Used for POST /transfer-requests endpoint
 */
const createTransferRequestSchema = z.object({
  admission_id: uuidSchema,
  from_ward_id: uuidSchema.optional().nullable(),
  to_ward_id: uuidSchema.optional().nullable(),
  status: z.enum(['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional(),
  requested_at: z.string().datetime().optional()
});

/**
 * Update transfer request body validation
 * Used for PUT /transfer-requests/:id endpoint
 * All fields optional for partial updates
 */
const updateTransferRequestSchema = z.object({
  admission_id: uuidSchema.optional(),
  from_ward_id: uuidSchema.optional().nullable(),
  to_ward_id: uuidSchema.optional().nullable(),
  status: z.enum(['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional(),
  requested_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Transfer request ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const transferRequestIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List transfer requests query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with transfer request-specific filters
 */
const listTransferRequestsQuerySchema = listQuerySchema.extend({
  admission_id: uuidSchema.optional(),
  from_ward_id: uuidSchema.optional(),
  to_ward_id: uuidSchema.optional(),
  status: z.enum(['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createTransferRequestSchema,
  updateTransferRequestSchema,
  transferRequestIdParamsSchema,
  listTransferRequestsQuerySchema
};
