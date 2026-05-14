/**
 * Radiology Result module validation schemas
 *
 * @module modules/radiology-result/schemas
 * @description Zod validation schemas for radiology-result endpoints.
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
 * Create radiology result body validation
 * Used for POST /radiology-results endpoint
 */
const createRadiologyResultSchema = z.object({
  radiology_order_id: uuidOrFriendlyIdentifierSchema,
  status: z.enum(['DRAFT', 'FINAL', 'AMENDED']),
  report_text: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional().nullable()
});

/**
 * Update radiology result body validation
 * Used for PUT /radiology-results/:id endpoint
 * All fields optional for partial updates
 */
const updateRadiologyResultSchema = z.object({
  radiology_order_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'FINAL', 'AMENDED']).optional(),
  report_text: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional().nullable()
});

/**
 * Sign off radiology result body validation
 * Used for POST /radiology-results/:id/sign-off endpoint
 */
const signOffRadiologyResultSchema = z.object({
  reported_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Radiology Result ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id endpoints
 */
const radiologyResultIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List radiology results query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with radiology-result-specific filters
 */
const listRadiologyResultsQuerySchema = listQuerySchema.extend({
  radiology_order_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'FINAL', 'AMENDED']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRadiologyResultSchema,
  updateRadiologyResultSchema,
  signOffRadiologyResultSchema,
  radiologyResultIdParamsSchema,
  listRadiologyResultsQuerySchema
};
