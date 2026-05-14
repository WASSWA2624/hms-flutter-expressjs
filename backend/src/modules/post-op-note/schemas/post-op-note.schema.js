/**
 * Post-op note module validation schemas
 *
 * @module modules/post-op-note/schemas
 * @description Zod validation schemas for post-op note endpoints.
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
 * Create post-op note body validation
 * Used for POST /post-op-notes endpoint
 */
const createPostOpNoteSchema = z.object({
  theatre_case_id: uuidOrFriendlyIdentifierSchema,
  note: z.string().trim().min(1),
  record_status: z.enum(['DRAFT', 'FINAL']).optional(),
  finalized_at: z.string().datetime().optional().nullable(),
  finalized_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopened_at: z.string().datetime().optional().nullable(),
  reopened_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopen_reason: z.string().trim().optional().nullable(),
});

/**
 * Update post-op note body validation
 * Used for PUT /post-op-notes/:id endpoint
 * All fields optional for partial updates
 */
const updatePostOpNoteSchema = z.object({
  theatre_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  note: z.string().trim().min(1).optional(),
  record_status: z.enum(['DRAFT', 'FINAL']).optional(),
  finalized_at: z.string().datetime().optional().nullable(),
  finalized_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopened_at: z.string().datetime().optional().nullable(),
  reopened_by_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reopen_reason: z.string().trim().optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Post-op note ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const postOpNoteIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List post-op notes query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with post-op note-specific filters
 */
const listPostOpNotesQuerySchema = listQuerySchema.extend({
  theatre_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  record_status: z.enum(['DRAFT', 'FINAL']).optional(),
  search: z.string().trim().optional(),
});

module.exports = {
  createPostOpNoteSchema,
  updatePostOpNoteSchema,
  postOpNoteIdParamsSchema,
  listPostOpNotesQuerySchema
};
