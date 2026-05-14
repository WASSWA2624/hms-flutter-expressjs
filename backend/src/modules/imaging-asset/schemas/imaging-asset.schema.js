/**
 * Imaging asset module validation schemas
 *
 * @module modules/imaging-asset/schemas
 * @description Zod validation schemas for imaging asset endpoints.
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
 * Create imaging asset body validation
 * Used for POST /imaging-assets endpoint
 */
const createImagingAssetSchema = z.object({
  imaging_study_id: uuidOrFriendlyIdentifierSchema,
  storage_key: z.string().trim().min(1).max(255),
  file_name: z.string().trim().max(255).optional().nullable(),
  content_type: z.string().trim().max(120).optional().nullable()
});

/**
 * Update imaging asset body validation
 * Used for PUT /imaging-assets/:id endpoint
 * All fields optional for partial updates
 */
const updateImagingAssetSchema = z.object({
  file_name: z.string().trim().max(255).optional().nullable(),
  content_type: z.string().trim().max(120).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Imaging asset ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const imagingAssetIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List imaging assets query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with imaging asset-specific filters
 */
const listImagingAssetsQuerySchema = listQuerySchema.extend({
  imaging_study_id: uuidOrFriendlyIdentifierSchema.optional(),
  content_type: z.string().trim().optional()
});

module.exports = {
  createImagingAssetSchema,
  updateImagingAssetSchema,
  imagingAssetIdParamsSchema,
  listImagingAssetsQuerySchema
};
