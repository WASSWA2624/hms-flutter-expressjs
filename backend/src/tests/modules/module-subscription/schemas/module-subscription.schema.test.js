/**
 * Module subscription schema validation tests
 *
 * @module tests/modules/module-subscription/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createModuleSubscriptionSchema,
  updateModuleSubscriptionSchema,
  moduleSubscriptionIdParamsSchema,
  listModuleSubscriptionsQuerySchema
} = require('@validations/module-subscription/module-subscription.schema');

describe('Module Subscription Schema Validation', () => {
  const validUuid = '123e4567-e89b-12d3-a456-426614174000';

  describe('createModuleSubscriptionSchema', () => {
    it('should validate correct module subscription data', () => {
      const validData = {
        module_id: validUuid,
        subscription_id: validUuid,
        is_active: true
      };
      const result = createModuleSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (without is_active)', () => {
      const validData = {
        module_id: validUuid,
        subscription_id: validUuid
      };
      const result = createModuleSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing module_id', () => {
      const invalidData = {
        subscription_id: validUuid
      };
      const result = createModuleSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing subscription_id', () => {
      const invalidData = {
        module_id: validUuid
      };
      const result = createModuleSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid module_id UUID', () => {
      const invalidData = {
        module_id: 'not-a-uuid',
        subscription_id: validUuid
      };
      const result = createModuleSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid subscription_id UUID', () => {
      const invalidData = {
        module_id: validUuid,
        subscription_id: 'not-a-uuid'
      };
      const result = createModuleSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateModuleSubscriptionSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        module_id: validUuid,
        subscription_id: validUuid,
        is_active: false
      };
      const result = updateModuleSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateModuleSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: false
      };
      const result = updateModuleSubscriptionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid module_id UUID', () => {
      const invalidData = {
        module_id: 'not-a-uuid'
      };
      const result = updateModuleSubscriptionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('moduleSubscriptionIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = { id: validUuid };
      const result = moduleSubscriptionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = { id: 'not-a-uuid' };
      const result = moduleSubscriptionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = moduleSubscriptionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listModuleSubscriptionsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listModuleSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with module_id filter', () => {
      const validData = { module_id: validUuid };
      const result = listModuleSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with subscription_id filter', () => {
      const validData = { subscription_id: validUuid };
      const result = listModuleSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = { is_active: 'true' };
      const result = listModuleSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = { is_active: 'maybe' };
      const result = listModuleSubscriptionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = { page: '2', limit: '30' };
      const result = listModuleSubscriptionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });
  });
});
