/**
 * Data processing log module validation schemas
 *
 * @module modules/data-processing-log/schemas
 * @description Zod validation schemas for data processing log endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create data processing log body validation
 * Used for POST /data-processing-logs endpoint
 */
const createDataProcessingLogSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  purpose: z.enum(['TREATMENT', 'BILLING', 'OPERATIONS', 'RESEARCH', 'MARKETING']),
  legal_basis: z.enum(['CONSENT', 'CONTRACT', 'LEGAL_OBLIGATION', 'VITAL_INTERESTS', 'PUBLIC_INTEREST', 'LEGITIMATE_INTERESTS']),
  details: z.string().trim().optional().nullable(),
});

/**
 * Update data processing log body validation
 * Used for PUT /data-processing-logs/:id endpoint
 * All fields optional for partial updates
 */
const updateDataProcessingLogSchema = z.object({
  purpose: z.enum(['TREATMENT', 'BILLING', 'OPERATIONS', 'RESEARCH', 'MARKETING']).optional(),
  legal_basis: z.enum(['CONSENT', 'CONTRACT', 'LEGAL_OBLIGATION', 'VITAL_INTERESTS', 'PUBLIC_INTEREST', 'LEGITIMATE_INTERESTS']).optional(),
  details: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Data processing log ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const dataProcessingLogIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

// ==================== Query Params ====================

/**
 * List data processing logs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with data-processing-log-specific filters
 */
const listDataProcessingLogsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  purpose: z.enum(['TREATMENT', 'BILLING', 'OPERATIONS', 'RESEARCH', 'MARKETING']).optional(),
  legal_basis: z.enum(['CONSENT', 'CONTRACT', 'LEGAL_OBLIGATION', 'VITAL_INTERESTS', 'PUBLIC_INTEREST', 'LEGITIMATE_INTERESTS']).optional(),
  search: z.string().trim().max(120).optional(),
  date_from: z.string().datetime().optional(),
  date_to: z.string().datetime().optional(),
});

module.exports = {
  createDataProcessingLogSchema,
  updateDataProcessingLogSchema,
  dataProcessingLogIdParamsSchema,
  listDataProcessingLogsQuerySchema
};
