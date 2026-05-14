/**
 * Conversation schema tests
 *
 * @module tests/modules/conversation/schemas
 * @description Tests for conversation validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createConversationSchema,
  updateConversationSchema,
  conversationIdParamsSchema,
  listConversationsQuerySchema
} = require('@validations/conversation/conversation.schema');

describe('Conversation Schemas', () => {
  describe('createConversationSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      subject: 'Test Conversation',
      created_by_user_id: '550e8400-e29b-41d4-a716-446655440001'
    };

    it('should validate correct conversation data', () => {
      const result = createConversationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createConversationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional subject', () => {
      const data = { ...validData };
      delete data.subject;
      const result = createConversationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional created_by_user_id', () => {
      const data = { ...validData };
      delete data.created_by_user_id;
      const result = createConversationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim subject', () => {
      const data = { ...validData, subject: '  Test  ' };
      const result = createConversationSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.subject).toBe('Test');
      }
    });

    it('should enforce max length for subject', () => {
      const data = { ...validData, subject: 'a'.repeat(256) };
      const result = createConversationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createConversationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateConversationSchema', () => {
    it('should validate optional subject', () => {
      const data = { subject: 'Updated Subject' };
      const result = updateConversationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const data = {};
      const result = updateConversationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim subject', () => {
      const data = { subject: '  Updated  ' };
      const result = updateConversationSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.subject).toBe('Updated');
      }
    });
  });

  describe('conversationIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = conversationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = conversationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const data = {};
      const result = conversationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listConversationsQuerySchema', () => {
    it('should validate empty query', () => {
      const data = {};
      const result = listConversationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with filters', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        created_by_user_id: '550e8400-e29b-41d4-a716-446655440001',
        subject: 'Test',
        search: 'keyword',
        page: '1',
        limit: '20'
      };
      const result = listConversationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept pagination parameters', () => {
      const data = { page: '2', limit: '50', sort_by: 'created_at', order: 'asc' };
      const result = listConversationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
