/**
 * Discharge summary module validation schemas
 *
 * @module modules/discharge-summary/schemas
 * @description Zod validation schemas for discharge summary endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// DischargeStatus enum values from Prisma schema
const DISCHARGE_STATUSES = ['PLANNED', 'COMPLETED', 'CANCELLED'];

// ==================== Body Schemas ====================

/**
 * Create discharge summary body validation
 * Used for POST /discharge-summaries endpoint
 */
const createDischargeSummarySchema = z.object({
  admission_id: uuidSchema,
  summary: z.string().trim().min(1).max(65535),
  status: z.enum(DISCHARGE_STATUSES),
  discharged_at: z.string().datetime().optional()
});

/**
 * Update discharge summary body validation
 * Used for PUT /discharge-summaries/:id endpoint
 * All fields optional for partial updates
 */
const updateDischargeSummarySchema = z.object({
  summary: z.string().trim().min(1).max(65535).optional(),
  status: z.enum(DISCHARGE_STATUSES).optional(),
  discharged_at: z.string().datetime().optional()
});

/**
 * Finalize discharge summary body validation
 * Used for POST /discharge-summaries/:id/finalize endpoint
 */
const finalizeDischargeSummarySchema = z.object({
  discharged_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Discharge summary ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const dischargeSummaryIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List discharge summaries query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with discharge summary-specific filters
 */
const listDischargeSummariesQuerySchema = listQuerySchema.extend({
  admission_id: uuidSchema.optional(),
  status: z.enum(DISCHARGE_STATUSES).optional()
});

module.exports = {
  createDischargeSummarySchema,
  updateDischargeSummarySchema,
  finalizeDischargeSummarySchema,
  dischargeSummaryIdParamsSchema,
  listDischargeSummariesQuerySchema
};
