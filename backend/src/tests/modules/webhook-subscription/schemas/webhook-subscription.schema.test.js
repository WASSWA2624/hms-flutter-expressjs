/**
 * Webhook subscription schema validation tests
 *
 * @module tests/modules/webhook-subscription/schemas
 * @description Tests for webhook subscription Zod validation schemas
 */

const {
  createWebhookSubscriptionSchema,
  updateWebhookSubscriptionSchema,
  webhookSubscriptionIdParamsSchema,
  listWebhookSubscriptionsQuerySchema
} = require('@validations/webhook-subscription/webhook-subscription.schema');

describe('Webhook Subscription Schema Validation', () => {
  describe('createWebhookSubscriptionSchema', () => {
    it('should validate friendly identifiers for tenant and integration', () => {
      const validData = {
        tenant_id: 'TEN0000001',
        integration_id: 'INT0000001',
        event: 'user.created',
        target_url: 'https://example.com/webhook',
        is_active: true
      };

      const result = createWebhookSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate valid webhook subscription creation data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_id: '223e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        target_url: 'https://example.com/webhook',
        is_active: true
      };

      const result = createWebhookSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate without optional integration_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        target_url: 'https://example.com/webhook'
      };

      const result = createWebhookSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should apply default is_active value', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        target_url: 'https://example.com/webhook'
      };

      const result = createWebhookSubscriptionSchema.parse(validData);
      expect(result.is_active).toBe(true);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        event: 'user.created',
        target_url: 'https://example.com/webhook'
      };

      const result = createWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid target_url format', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        target_url: 'not-a-valid-url'
      };

      const result = createWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty event', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        event: '',
        target_url: 'https://example.com/webhook'
      };

      const result = createWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject event exceeding 120 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        event: 'a'.repeat(121),
        target_url: 'https://example.com/webhook'
      };

      const result = createWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject target_url exceeding 255 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        target_url: 'https://example.com/' + 'a'.repeat(250)
      };

      const result = createWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateWebhookSubscriptionSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        integration_id: '223e4567-e89b-12d3-a456-426614174000',
        event: 'user.updated',
        target_url: 'https://example.com/new-webhook',
        is_active: false
      };

      const result = updateWebhookSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate partial update data', () => {
      const validData = {
        is_active: false
      };

      const result = updateWebhookSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty object (all optional)', () => {
      const validData = {};

      const result = updateWebhookSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid target_url', () => {
      const invalidData = {
        target_url: 'not-a-url'
      };

      const result = updateWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty event', () => {
      const invalidData = {
        event: ''
      };

      const result = updateWebhookSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('webhookSubscriptionIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = webhookSubscriptionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate a friendly identifier', () => {
      const validData = {
        id: 'WHS0000001'
      };

      const result = webhookSubscriptionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };

      const result = webhookSubscriptionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};

      const result = webhookSubscriptionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listWebhookSubscriptionsQuerySchema', () => {
    it('should validate valid query parameters', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'event',
        order: 'asc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_id: '223e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        is_active: 'true',
        search: 'webhook'
      };

      const result = listWebhookSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal parameters', () => {
      const validData = {};

      const result = listWebhookSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate friendly tenant and integration filters', () => {
      const validData = {
        tenant_id: 'TEN0000001',
        integration_id: 'INT0000001'
      };

      const result = listWebhookSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should transform is_active string to boolean', () => {
      const validData = {
        is_active: 'true'
      };

      const result = listWebhookSubscriptionsQuerySchema.parse(validData);
      expect(result.is_active).toBe(true);
    });

    it('should reject invalid UUID for tenant_id', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid'
      };

      const result = listWebhookSubscriptionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for integration_id', () => {
      const invalidData = {
        integration_id: 'invalid-uuid'
      };

      const result = listWebhookSubscriptionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should accept valid is_active values', () => {
      const validTrue = listWebhookSubscriptionsQuerySchema.safeParse({ is_active: 'true' });
      const validFalse = listWebhookSubscriptionsQuerySchema.safeParse({ is_active: 'false' });
      
      expect(validTrue.success).toBe(true);
      expect(validFalse.success).toBe(true);
    });
  });
});
