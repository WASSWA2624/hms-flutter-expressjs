/**
 * Message module validation schemas
 *
 * @module modules/message/schemas
 * @description Zod validation schemas for message endpoints.
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
 * Create message body validation
 * Used for POST /messages endpoint
 */
const createMessageSchema = z.object({
  conversation_id: uuidSchema,
  sender_user_id: uuidSchema.optional().nullable(),
  sender_patient_id: uuidSchema.optional().nullable(),
  content: z.string().trim().min(1),
  sent_at: z.string().datetime().optional()
});

/**
 * Update message body validation
 * Used for PUT /messages/:id endpoint
 * All fields optional for partial updates
 */
const updateMessageSchema = z.object({
  content: z.string().trim().min(1).optional()
});

// ==================== URL Params ====================

/**
 * Message ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const messageIdParamsSchema = z.object({
  id: uuidSchema
});

/**
 * Conversation ID URL parameter validation
 * Used for GET /conversation/:conversationId endpoint
 */
const conversationIdParamsSchema = z.object({
  conversationId: uuidSchema
});

// ==================== Query Params ====================

/**
 * List messages query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with message-specific filters
 */
const listMessagesQuerySchema = listQuerySchema.extend({
  conversation_id: uuidSchema.optional(),
  sender_user_id: uuidSchema.optional(),
  sender_patient_id: uuidSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createMessageSchema,
  updateMessageSchema,
  messageIdParamsSchema,
  conversationIdParamsSchema,
  listMessagesQuerySchema
};
