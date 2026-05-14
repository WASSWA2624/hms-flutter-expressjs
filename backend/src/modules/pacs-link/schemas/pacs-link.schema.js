/**
 * PACS link module validation schemas
 *
 * @module modules/pacs-link/schemas
 * @description Zod validation schemas for PACS link endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema,
  urlSchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create PACS link body validation
 * Used for POST /pacs-links endpoint
 */
const createPacsLinkSchema = z.object({
  imaging_study_id: uuidOrFriendlyIdentifierSchema,
  url: urlSchema,
  expires_at: isoDateSchema.optional().nullable()
});

/**
 * Update PACS link body validation
 * Used for PUT /pacs-links/:id endpoint
 * All fields optional for partial updates
 */
const updatePacsLinkSchema = z.object({
  url: urlSchema.optional(),
  expires_at: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * PACS link ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const pacsLinkIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List PACS links query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with PACS link-specific filters
 */
const listPacsLinksQuerySchema = listQuerySchema.extend({
  imaging_study_id: uuidOrFriendlyIdentifierSchema.optional(),
  expires_at: isoDateSchema.optional()
});

module.exports = {
  createPacsLinkSchema,
  updatePacsLinkSchema,
  pacsLinkIdParamsSchema,
  listPacsLinksQuerySchema
};
