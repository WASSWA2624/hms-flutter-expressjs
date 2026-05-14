/**
 * Adverse Event module validation schemas
 *
 * @module modules/adverse-event/schemas
 * @description Zod validation schemas for adverse event endpoints.
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
 * Create adverse event body validation
 * Used for POST /adverse-events endpoint
 */
const createAdverseEventSchema = z.object({
  patient_id: uuidSchema,
  drug_id: uuidSchema.optional().nullable(),
  severity: z.enum(['MILD', 'MODERATE', 'SEVERE']),
  description: z.string().trim().max(65535).optional().nullable(),
  reported_at: isoDateSchema.optional()
});

/**
 * Update adverse event body validation
 * Used for PUT /adverse-events/:id endpoint
 * All fields optional for partial updates
 */
const updateAdverseEventSchema = z.object({
  drug_id: uuidSchema.optional().nullable(),
  severity: z.enum(['MILD', 'MODERATE', 'SEVERE']).optional(),
  description: z.string().trim().max(65535).optional().nullable(),
  reported_at: isoDateSchema.optional()
});

// ==================== URL Params ====================

/**
 * Adverse event ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const adverseEventIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List adverse events query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with adverse event-specific filters
 */
const listAdverseEventsQuerySchema = listQuerySchema.extend({
  patient_id: uuidSchema.optional(),
  drug_id: uuidSchema.optional(),
  severity: z.enum(['MILD', 'MODERATE', 'SEVERE']).optional(),
  reported_at_from: isoDateSchema.optional(),
  reported_at_to: isoDateSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAdverseEventSchema,
  updateAdverseEventSchema,
  adverseEventIdParamsSchema,
  listAdverseEventsQuerySchema
};
