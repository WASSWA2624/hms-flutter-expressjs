/**
 * Consent module validation schemas
 *
 * @module modules/consent/schemas
 * @description Zod validation schemas for consent endpoints.
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
 * Create consent body validation
 * Used for POST /consents endpoint
 */
const createConsentSchema = z.object({
  patient_id: uuidSchema,
  consent_type: z.enum(['TREATMENT', 'DATA_SHARING', 'RESEARCH', 'BILLING', 'OTHER']),
  status: z.enum(['GRANTED', 'REVOKED', 'PENDING']),
  granted_at: z.string().datetime().optional().nullable(),
  revoked_at: z.string().datetime().optional().nullable()
});

/**
 * Update consent body validation
 * Used for PUT /consents/:id endpoint
 * All fields optional for partial updates
 */
const updateConsentSchema = z.object({
  consent_type: z.enum(['TREATMENT', 'DATA_SHARING', 'RESEARCH', 'BILLING', 'OTHER']).optional(),
  status: z.enum(['GRANTED', 'REVOKED', 'PENDING']).optional(),
  granted_at: z.string().datetime().optional().nullable(),
  revoked_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Consent ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const consentIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List consents query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with consent-specific filters
 */
const listConsentsQuerySchema = listQuerySchema.extend({
  patient_id: uuidSchema.optional(),
  consent_type: z.enum(['TREATMENT', 'DATA_SHARING', 'RESEARCH', 'BILLING', 'OTHER']).optional(),
  status: z.enum(['GRANTED', 'REVOKED', 'PENDING']).optional()
});

module.exports = {
  createConsentSchema,
  updateConsentSchema,
  consentIdParamsSchema,
  listConsentsQuerySchema
};
