/**
 * API Key Permission module validation schemas
 *
 * @module modules/api-key-permission/schemas
 * @description Zod validation schemas for API key permission endpoints.
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
 * Create API key permission body validation
 * Used for POST /api-key-permissions endpoint
 */
const createApiKeyPermissionSchema = z.object({
  api_key_id: uuidSchema,
  permission_id: uuidSchema
});

/**
 * Update API key permission body validation
 * Used for PUT /api-key-permissions/:id endpoint
 * All fields optional for partial updates
 */
const updateApiKeyPermissionSchema = z.object({
  api_key_id: uuidSchema.optional(),
  permission_id: uuidSchema.optional()
});

// ==================== URL Params ====================

/**
 * API Key Permission ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const apiKeyPermissionIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List API key permissions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with api-key-permission-specific filters
 */
const listApiKeyPermissionsQuerySchema = listQuerySchema.extend({
  api_key_id: uuidSchema.optional(),
  permission_id: uuidSchema.optional()
});

module.exports = {
  createApiKeyPermissionSchema,
  updateApiKeyPermissionSchema,
  apiKeyPermissionIdParamsSchema,
  listApiKeyPermissionsQuerySchema
};
