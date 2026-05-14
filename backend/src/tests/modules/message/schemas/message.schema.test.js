/**
 * Message schema tests
 *
 * @module tests/modules/message/schemas
 * @description Tests for message validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createMessageSchema,
  updateMessageSchema,
  messageIdParamsSchema,
  conversationIdParamsSchema,
  listMessagesQuerySchema
} = require('@validations/message/message.schema');

describe('Message Schemas', () => {
  describe('createMessageSchema', () => {
    const validData = {
      conversation_id: '550e8400-e29b-41d4-a716-446655440000',
      sender_user_id: '550e8400-e29b-41d4-a716-446655440001',
      content: 'Test message content',
      sent_at: '2024-01-01T00:00:00.000Z'
    };

    it('should validate correct message data', () => {
      const result = createMessageSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require conversation_id', () => {
      const data = { ...validData };
      delete data.conversation_id;
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require content', () => {
      const data = { ...validData };
      delete data.content;
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional sender_user_id', () => {
      const data = { ...validData };
      delete data.sender_user_id;
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional sender_patient_id', () => {
      const data = { ...validData, sender_patient_id: '550e8400-e29b-41d4-a716-446655440002' };
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional sent_at', () => {
      const data = { ...validData };
      delete data.sent_at;
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim content', () => {
      const data = { ...validData, content: '  Test  ' };
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.content).toBe('Test');
      }
    });

    it('should validate UUID format for conversation_id', () => {
      const data = { ...validData, conversation_id: 'invalid-uuid' };
      const result = createMessageSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateMessageSchema', () => {
    it('should validate optional content', () => {
      const data = { content: 'Updated content' };
      const result = updateMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const data = {};
      const result = updateMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim content', () => {
      const data = { content: '  Updated  ' };
      const result = updateMessageSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.content).toBe('Updated');
      }
    });
  });

  describe('messageIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = messageIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = messageIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('conversationIdParamsSchema', () => {
    it('should validate valid conversationId', () => {
      const data = { conversationId: '550e8400-e29b-41d4-a716-446655440000' };
      const result = conversationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid conversationId', () => {
      const data = { conversationId: 'invalid-uuid' };
      const result = conversationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listMessagesQuerySchema', () => {
    it('should validate empty query', () => {
      const data = {};
      const result = listMessagesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with filters', () => {
      const data = {
        conversation_id: '550e8400-e29b-41d4-a716-446655440000',
        sender_user_id: '550e8400-e29b-41d4-a716-446655440001',
        search: 'keyword'
      };
      const result = listMessagesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
