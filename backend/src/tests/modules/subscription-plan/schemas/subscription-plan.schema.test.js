/**
 * Subscription Plan schema tests
 *
 * @module tests/modules/subscription-plan/schemas
 * @description Tests for subscription plan validation schemas
 */

const {
  createSubscriptionPlanSchema,
  updateSubscriptionPlanSchema,
  subscriptionPlanIdParamsSchema,
  listSubscriptionPlansQuerySchema
} = require('../../../../modules/subscription-plan/schemas/subscription-plan.schema');

describe('Subscription Plan Schemas', () => {
  describe('createSubscriptionPlanSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Basic Plan',
        code: 'BASIC',
        tier_code: 'BASIC',
        price: 99.99,
        billing_cycle: 'MONTHLY',
        max_users: 25,
        max_modules: 10,
        limit_policy_json: {
          warning_percent: 80
        },
        extension_json: {
          allowed_modules: {
            included: ['appointments']
          }
        }
      };

      const result = createSubscriptionPlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow null tenant_id', () => {
      const validData = {
        tenant_id: null,
        name: 'Basic Plan',
        price: 99.99,
        billing_cycle: 'MONTHLY'
      };

      const result = createSubscriptionPlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createSubscriptionPlanSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative price', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Basic Plan',
        price: -10,
        billing_cycle: 'MONTHLY'
      };

      const result = createSubscriptionPlanSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid billing_cycle', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Basic Plan',
        price: 99.99,
        billing_cycle: 'INVALID'
      };

      const result = createSubscriptionPlanSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateSubscriptionPlanSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        name: 'Updated Plan',
        price: 149.99,
        billing_cycle: 'YEARLY'
      };

      const result = updateSubscriptionPlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const validData = {
        extension_json: {
          allowed_modules: {
            blocked: ['analytics']
          }
        }
      };

      const result = updateSubscriptionPlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject negative price', () => {
      const invalidData = {
        price: -50
      };

      const result = updateSubscriptionPlanSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid plan fit warning percent', () => {
      const invalidData = {
        plan_fit_warning_percent: 150
      };

      const result = updateSubscriptionPlanSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('subscriptionPlanIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = subscriptionPlanIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = subscriptionPlanIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listSubscriptionPlansQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        billing_cycle: 'MONTHLY',
        search: 'basic'
      };

      const result = listSubscriptionPlansQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow minimal query params', () => {
      const validData = {};

      const result = listSubscriptionPlansQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid billing_cycle', () => {
      const invalidData = {
        billing_cycle: 'INVALID'
      };

      const result = listSubscriptionPlansQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
