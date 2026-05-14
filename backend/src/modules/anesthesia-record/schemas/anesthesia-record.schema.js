/**
 * Anesthesia record module validation schemas
 *
 * @module modules/anesthesia-record/schemas
 * @description Zod validation schemas for anesthesia record endpoints.
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
 * Create anesthesia record body validation
 * Used for POST /anesthesia-records endpoint
 */
const createAnesthesiaRecordSchema = z.object({
  theatre_case_id: uuidOrFriendlyIdentifierSchema,
  anesthetist_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  notes: z.string().trim().optional().nullable(),
  record_status: z.enum(['DRAFT', 'FINAL']).optional(),
  finalized_at: z.string().datetime().optional().nullable(),
  finalized_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopened_at: z.string().datetime().optional().nullable(),
  reopened_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopen_reason: z.string().trim().optional().nullable(),
});

/**
 * Update anesthesia record body validation
 * Used for PUT /anesthesia-records/:id endpoint
 * All fields optional for partial updates
 */
const updateAnesthesiaRecordSchema = z.object({
  theatre_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  anesthetist_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  notes: z.string().trim().optional().nullable(),
  record_status: z.enum(['DRAFT', 'FINAL']).optional(),
  finalized_at: z.string().datetime().optional().nullable(),
  finalized_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopened_at: z.string().datetime().optional().nullable(),
  reopened_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopen_reason: z.string().trim().optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Anesthesia record ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const anesthesiaRecordIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List anesthesia records query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with anesthesia record-specific filters
 */
const listAnesthesiaRecordsQuerySchema = listQuerySchema.extend({
  theatre_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  anesthetist_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  record_status: z.enum(['DRAFT', 'FINAL']).optional(),
  search: z.string().trim().optional(),
});

module.exports = {
  createAnesthesiaRecordSchema,
  updateAnesthesiaRecordSchema,
  anesthesiaRecordIdParamsSchema,
  listAnesthesiaRecordsQuerySchema
};
