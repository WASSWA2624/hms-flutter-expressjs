/**
 * Nursing note module validation schemas
 *
 * @module modules/nursing-note/schemas
 * @description Zod validation schemas for nursing note endpoints.
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
 * Create nursing note body validation
 * Used for POST /nursing-notes endpoint
 */
const createNursingNoteSchema = z.object({
  admission_id: uuidOrFriendlyIdentifierSchema,
  nurse_user_id: uuidOrFriendlyIdentifierSchema,
  note: z.string().trim().min(1).max(65535)
});

/**
 * Update nursing note body validation
 * Used for PUT /nursing-notes/:id endpoint
 * All fields optional for partial updates
 */
const updateNursingNoteSchema = z.object({
  note: z.string().trim().min(1).max(65535).optional()
});

// ==================== URL Params ====================

/**
 * Nursing note ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const nursingNoteIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List nursing notes query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with nursing note-specific filters
 */
const listNursingNotesQuerySchema = listQuerySchema.extend({
  admission_id: uuidOrFriendlyIdentifierSchema.optional(),
  nurse_user_id: uuidOrFriendlyIdentifierSchema.optional()
});

module.exports = {
  createNursingNoteSchema,
  updateNursingNoteSchema,
  nursingNoteIdParamsSchema,
  listNursingNotesQuerySchema
};
