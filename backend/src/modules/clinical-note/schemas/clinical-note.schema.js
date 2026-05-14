/**
 * Clinical note module validation schemas
 *
 * @module modules/clinical-note/schemas
 * @description Zod validation schemas for clinical note endpoints.
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
 * Create clinical note body validation
 * Used for POST /clinical-notes endpoint
 */
const createClinicalNoteSchema = z.object({
  encounter_id: uuidSchema,
  author_user_id: uuidSchema,
  note: z.string().trim().min(1).max(65535)
});

/**
 * Update clinical note body validation
 * Used for PUT /clinical-notes/:id endpoint
 * All fields optional for partial updates
 */
const updateClinicalNoteSchema = z.object({
  note: z.string().trim().min(1).max(65535).optional()
});

// ==================== URL Params ====================

/**
 * Clinical note ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const clinicalNoteIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List clinical notes query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with clinical note-specific filters
 */
const listClinicalNotesQuerySchema = listQuerySchema.extend({
  encounter_id: uuidSchema.optional(),
  author_user_id: uuidSchema.optional()
});

module.exports = {
  createClinicalNoteSchema,
  updateClinicalNoteSchema,
  clinicalNoteIdParamsSchema,
  listClinicalNotesQuerySchema
};
