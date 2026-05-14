/**
 * API Key module validation schemas
 *
 * @module modules/api-key/schemas
 * @description Zod validation schemas for API key endpoints.
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
 * Create API key body validation
 * Used for POST /api-keys endpoint
 */
const createApiKeySchema = z.object({
  tenant_id: uuidSchema,
  user_id: uuidSchema,
  name: z.string().trim().min(1).max(120),
  expires_at: isoDateSchema.optional().nullable()
});

/**
 * Update API key body validation
 * Used for PUT /api-keys/:id endpoint
 * All fields optional for partial updates
 */
const updateApiKeySchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  is_active: z.boolean().optional(),
  expires_at: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * API Key ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const apiKeyIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List API keys query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with api-key-specific filters
 */
const listApiKeysQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  user_id: uuidSchema.optional(),
  is_active: z.enum(['true', 'false']).transform(val => val === 'true').optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createApiKeySchema,
  updateApiKeySchema,
  apiKeyIdParamsSchema,
  listApiKeysQuerySchema
};
