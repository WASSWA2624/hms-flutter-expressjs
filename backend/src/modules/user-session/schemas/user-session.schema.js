/**
 * User Session module validation schemas
 *
 * @module modules/user-session/schemas
 * @description Zod validation schemas for user session endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema 
} = require('@lib/validation/zod');

// ==================== URL Params ====================

/**
 * Session ID URL parameter validation
 * Used for GET /:id and DELETE /:id endpoints
 */
const sessionIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List sessions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with session-specific filters
 */
const listSessionsQuerySchema = listQuerySchema.extend({
  user_id: uuidSchema.optional(),
  is_active: z.enum(['true', 'false']).optional()
});

module.exports = {
  sessionIdParamsSchema,
  listSessionsQuerySchema
};
