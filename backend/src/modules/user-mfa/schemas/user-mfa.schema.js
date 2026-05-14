/**
 * User MFA module validation schemas
 *
 * @module modules/user-mfa/schemas
 * @description Zod validation schemas for user MFA endpoints.
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
 * Create user MFA body validation
 * Used for POST /user-mfas endpoint
 */
const createUserMfaSchema = z.object({
  user_id: uuidSchema,
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']),
  secret_encrypted: z.string().trim().min(1).max(255),
  is_enabled: z.boolean().optional()
});

/**
 * Update user MFA body validation
 * Used for PUT /user-mfas/:id endpoint
 * All fields optional for partial updates
 */
const updateUserMfaSchema = z.object({
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']).optional(),
  secret_encrypted: z.string().trim().min(1).max(255).optional(),
  is_enabled: z.boolean().optional()
});

/**
 * Verify MFA code body validation
 * Used for POST /user-mfas/:id/verify endpoint
 */
const verifyMfaCodeSchema = z.object({
  code: z.string().trim().min(6).max(10)
});

// ==================== URL Params ====================

/**
 * User MFA ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and action endpoints
 */
const userMfaIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List user MFAs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with user-mfa-specific filters
 */
const listUserMfasQuerySchema = listQuerySchema.extend({
  user_id: uuidSchema.optional(),
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']).optional(),
  is_enabled: z.enum(['true', 'false']).optional()
});

module.exports = {
  createUserMfaSchema,
  updateUserMfaSchema,
  verifyMfaCodeSchema,
  userMfaIdParamsSchema,
  listUserMfasQuerySchema
};
