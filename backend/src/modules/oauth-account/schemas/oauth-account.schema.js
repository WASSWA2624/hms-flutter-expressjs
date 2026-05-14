/**
 * OAuth Account module validation schemas
 *
 * @module modules/oauth-account/schemas
 * @description Zod validation schemas for OAuth account endpoints.
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
 * Create OAuth account body validation
 * Used for POST /oauth-accounts endpoint
 */
const createOAuthAccountSchema = z.object({
  user_id: uuidSchema,
  provider: z.string().trim().min(1).max(80),
  provider_user_id: z.string().trim().min(1).max(191),
  access_token_encrypted: z.string().trim().min(1).max(255).optional().nullable(),
  refresh_token_encrypted: z.string().trim().min(1).max(255).optional().nullable(),
  expires_at: z.string().datetime().optional().nullable()
});

/**
 * Update OAuth account body validation
 * Used for PUT /oauth-accounts/:id endpoint
 * All fields optional for partial updates
 */
const updateOAuthAccountSchema = z.object({
  provider: z.string().trim().min(1).max(80).optional(),
  provider_user_id: z.string().trim().min(1).max(191).optional(),
  access_token_encrypted: z.string().trim().min(1).max(255).optional().nullable(),
  refresh_token_encrypted: z.string().trim().min(1).max(255).optional().nullable(),
  expires_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * OAuth Account ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const oauthAccountIdParamsSchema = z.object({
  id: uuidSchema
});

/**
 * User ID URL parameter validation
 * Used for GET /user/:userId endpoint
 */
const userIdParamsSchema = z.object({
  userId: uuidSchema
});

// ==================== Query Params ====================

/**
 * List OAuth accounts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with oauth-account-specific filters
 */
const listOAuthAccountsQuerySchema = listQuerySchema.extend({
  user_id: uuidSchema.optional(),
  provider: z.string().trim().optional()
});

module.exports = {
  createOAuthAccountSchema,
  updateOAuthAccountSchema,
  oauthAccountIdParamsSchema,
  userIdParamsSchema,
  listOAuthAccountsQuerySchema
};
