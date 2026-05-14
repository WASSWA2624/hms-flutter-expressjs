/**
 * Pricing Rule schema tests
 *
 * @module tests/modules/pricing-rule/schemas
 * @description Tests for pricing rule validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPricingRuleSchema,
  updatePricingRuleSchema,
  pricingRuleIdParamsSchema,
  listPricingRulesQuerySchema
} = require('@validations/pricing-rule/pricing-rule.schema');

describe('Pricing Rule Schemas', () => {
  describe('createPricingRuleSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Standard Consultation',
      description: 'Standard consultation pricing rule',
      amount: 50.00,
      currency: 'USD',
      effective_from: '2024-01-01T00:00:00.000Z',
      effective_to: '2024-12-31T23:59:59.999Z'
    };

    it('should validate correct pricing rule data', () => {
      const result = createPricingRuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require amount', () => {
      const data = { ...validData };
      delete data.amount;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require currency', () => {
      const data = { ...validData };
      delete data.currency;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject negative amount', () => {
      const data = { ...validData, amount: -10 };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept zero amount', () => {
      const data = { ...validData, amount: 0 };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate currency length', () => {
      const data = { ...validData, currency: 'US' };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate currency is uppercase', () => {
      const data = { ...validData, currency: 'usd' };
      const result = createPricingRuleSchema.safeParse(data);
      // Currency should be transformed to uppercase
      const parsed = createPricingRuleSchema.safeParse(data);
      expect(parsed.success).toBe(true);
      if (parsed.success) {
        expect(parsed.data.currency).toBe('USD');
      }
    });

    it('should allow optional description', () => {
      const data = { ...validData };
      delete data.description;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional effective_from', () => {
      const data = { ...validData };
      delete data.effective_from;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional effective_to', () => {
      const data = { ...validData };
      delete data.effective_to;
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate effective_from datetime format', () => {
      const data = { ...validData, effective_from: 'invalid-date' };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate effective_to datetime format', () => {
      const data = { ...validData, effective_to: 'invalid-date' };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string fields', () => {
      const data = {
        ...validData,
        name: '  Test Name  ',
        description: '  Test Description  ',
        currency: ' USD '
      };
      const result = createPricingRuleSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Test Name');
        expect(result.data.description).toBe('Test Description');
        expect(result.data.currency).toBe('USD');
      }
    });
  });

  describe('updatePricingRuleSchema', () => {
    const validData = {
      name: 'Updated Name',
      description: 'Updated description',
      amount: 75.00,
      currency: 'USD',
      effective_from: '2024-01-01T00:00:00.000Z',
      effective_to: '2024-12-31T23:59:59.999Z'
    };

    it('should validate correct update data', () => {
      const result = updatePricingRuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow empty update object', () => {
      const result = updatePricingRuleSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const result = updatePricingRuleSchema.safeParse({ name: 'New Name' });
      expect(result.success).toBe(true);
    });

    it('should validate amount if provided', () => {
      const data = { amount: -10 };
      const result = updatePricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate currency length if provided', () => {
      const data = { currency: 'US' };
      const result = updatePricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format if provided', () => {
      const data = { effective_from: 'invalid-date' };
      const result = updatePricingRuleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('pricingRuleIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = pricingRuleIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = pricingRuleIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = pricingRuleIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listPricingRulesQuerySchema', () => {
    it('should validate correct query params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Test',
        currency: 'USD',
        search: 'consultation',
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };
      const result = listPricingRulesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty query params', () => {
      const result = listPricingRulesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate tenant_id UUID format', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listPricingRulesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional filters', () => {
      const data = { name: 'Test' };
      const result = listPricingRulesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate currency length', () => {
      const data = { currency: 'US' };
      const result = listPricingRulesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
