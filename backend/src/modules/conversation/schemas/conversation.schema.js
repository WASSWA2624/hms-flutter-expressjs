/**
 * Conversation module validation schemas
 *
 * @module modules/conversation/schemas
 * @description Zod validation schemas for conversation endpoints.
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
 * Create conversation body validation
 * Used for POST /conversations endpoint
 */
const createConversationSchema = z.object({
  tenant_id: uuidSchema,
  subject: z.string().trim().min(1).max(255).optional().nullable(),
  created_by_user_id: uuidSchema.optional().nullable()
});

/**
 * Update conversation body validation
 * Used for PUT /conversations/:id endpoint
 * All fields optional for partial updates
 */
const updateConversationSchema = z.object({
  subject: z.string().trim().min(1).max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Conversation ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const conversationIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List conversations query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with conversation-specific filters
 */
const listConversationsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  created_by_user_id: uuidSchema.optional(),
  subject: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createConversationSchema,
  updateConversationSchema,
  conversationIdParamsSchema,
  listConversationsQuerySchema
};
