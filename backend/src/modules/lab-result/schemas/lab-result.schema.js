/**
 * Lab result module validation schemas
 *
 * @module modules/lab-result/schemas
 * @description Zod validation schemas for lab result endpoints.
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
 * Create lab result body validation
 * Used for POST /lab-results endpoint
 */
const createLabResultSchema = z.object({
  lab_order_item_id: uuidOrFriendlyIdentifierSchema,
  status: z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING']).optional(),
  result_value: z.string().trim().max(120).optional().nullable(),
  result_unit: z.string().trim().max(40).optional().nullable(),
  result_text: z.string().optional().nullable(),
  reported_at: z.string().datetime().optional().nullable()
});

/**
 * Update lab result body validation
 * Used for PUT /lab-results/:id endpoint
 * All fields optional for partial updates
 */
const updateLabResultSchema = z.object({
  status: z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING']).optional(),
  result_value: z.string().trim().max(120).optional().nullable(),
  result_unit: z.string().trim().max(40).optional().nullable(),
  result_text: z.string().optional().nullable(),
  reported_at: z.string().datetime().optional().nullable()
});

/**
 * Release lab result body validation
 * Used for POST /lab-results/:id/release endpoint
 */
const releaseLabResultSchema = z.object({
  status: z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL']).optional(),
  reported_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Lab result ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const labResultIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List lab results query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with lab-result-specific filters
 */
const listLabResultsQuerySchema = listQuerySchema.extend({
  lab_order_item_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createLabResultSchema,
  updateLabResultSchema,
  releaseLabResultSchema,
  labResultIdParamsSchema,
  listLabResultsQuerySchema
};
