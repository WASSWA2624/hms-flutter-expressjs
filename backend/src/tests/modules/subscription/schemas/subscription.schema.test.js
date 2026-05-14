/**
 * Subscription schema tests
 *
 * @module tests/modules/subscription/schemas
 * @description Tests for subscription validation schemas
 */

const {
  createSubscriptionSchema,
  updateSubscriptionSchema,
  subscriptionIdParamsSchema,
  listSubscriptionsQuerySchema
} = require('../../../../modules/subscription/schemas/subscription.schema');

describe('Subscription Schemas', () => {
  describe('createSubscriptionSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        plan_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'ACTIVE',
        start_date: '2024-01-01T00:00:00.000Z',
        end_date: '2025-01-01T00:00:00.000Z',
        extension_json: {
          module_overrides: {
            allowed: ['biomed']
          }
        }
      };

      const result = createSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate minimal required data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        plan_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      const result = createSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        plan_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'INVALID'
      };

      const result = createSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should accept all valid statuses', () => {
      const statuses = ['ACTIVE', 'PAST_DUE', 'CANCELLED', 'TRIAL'];

      statuses.forEach(status => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          plan_id: '123e4567-e89b-12d3-a456-426614174001',
          status
        };

        const result = createSubscriptionSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });
  });

  describe('updateSubscriptionSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        plan_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'CANCELLED',
        end_date: '2025-01-01T00:00:00.000Z',
        extension_json: {
          module_overrides: {
            blocked: ['analytics']
          }
        }
      };

      const result = updateSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const validData = {
        status: 'ACTIVE'
      };

      const result = updateSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow null end_date', () => {
      const validData = {
        end_date: null
      };

      const result = updateSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow null extension_json to clear custom overrides', () => {
      const validData = {
        extension_json: null
      };

      const result = updateSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('subscriptionIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = subscriptionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = subscriptionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listSubscriptionsQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        plan_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'ACTIVE',
        search: 'test'
      };

      const result = listSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow minimal query params', () => {
      const validData = {};

      const result = listSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID'
      };

      const result = listSubscriptionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
