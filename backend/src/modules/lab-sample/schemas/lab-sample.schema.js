/**
 * Lab sample module validation schemas
 *
 * @module modules/lab-sample/schemas
 * @description Zod validation schemas for lab sample endpoints.
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
 * Create lab sample body validation
 * Used for POST /lab-samples endpoint
 */
const createLabSampleSchema = z.object({
  lab_order_id: uuidOrFriendlyIdentifierSchema,
  status: z.enum(['PENDING', 'COLLECTED', 'REJECTED', 'RECEIVED']),
  collected_at: z.string().datetime().optional().nullable(),
  received_at: z.string().datetime().optional().nullable()
});

/**
 * Update lab sample body validation
 * Used for PUT /lab-samples/:id endpoint
 * All fields optional for partial updates
 */
const updateLabSampleSchema = z.object({
  status: z.enum(['PENDING', 'COLLECTED', 'REJECTED', 'RECEIVED']).optional(),
  collected_at: z.string().datetime().optional().nullable(),
  received_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Lab sample ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const labSampleIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List lab samples query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with lab-sample-specific filters
 */
const listLabSamplesQuerySchema = listQuerySchema.extend({
  lab_order_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['PENDING', 'COLLECTED', 'REJECTED', 'RECEIVED']).optional(),
  created_at_from: z.string().datetime().optional(),
  created_at_to: z.string().datetime().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createLabSampleSchema,
  updateLabSampleSchema,
  labSampleIdParamsSchema,
  listLabSamplesQuerySchema
};
