/**
 * Coverage Plan schema tests
 *
 * @module tests/modules/coverage-plan/schemas
 * @description Tests for coverage plan validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createCoveragePlanSchema,
  updateCoveragePlanSchema,
  coveragePlanIdParamsSchema,
  listCoveragePlansQuerySchema
} = require('@validations/coverage-plan/coverage-plan.schema');

describe('Coverage Plan Schemas', () => {
  describe('createCoveragePlanSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Basic Health Plan',
      provider_name: 'HealthCare Inc',
      coverage_percentage: 80
    };

    it('should validate correct coverage plan data', () => {
      const result = createCoveragePlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional provider_name', () => {
      const data = { ...validData };
      delete data.provider_name;
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional coverage_percentage', () => {
      const data = { ...validData };
      delete data.coverage_percentage;
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate coverage_percentage range (0-100)', () => {
      const data = { ...validData, coverage_percentage: 101 };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject negative coverage_percentage', () => {
      const data = { ...validData, coverage_percentage: -1 };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept zero coverage_percentage', () => {
      const data = { ...validData, coverage_percentage: 0 };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept 100 coverage_percentage', () => {
      const data = { ...validData, coverage_percentage: 100 };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject non-integer coverage_percentage', () => {
      const data = { ...validData, coverage_percentage: 75.5 };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string fields', () => {
      const data = {
        ...validData,
        name: '  Test Plan  ',
        provider_name: '  Test Provider  '
      };
      const result = createCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Test Plan');
        expect(result.data.provider_name).toBe('Test Provider');
      }
    });
  });

  describe('updateCoveragePlanSchema', () => {
    const validData = {
      name: 'Updated Plan',
      provider_name: 'Updated Provider',
      coverage_percentage: 90
    };

    it('should validate correct update data', () => {
      const result = updateCoveragePlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow empty update object', () => {
      const result = updateCoveragePlanSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const result = updateCoveragePlanSchema.safeParse({ name: 'New Name' });
      expect(result.success).toBe(true);
    });

    it('should validate coverage_percentage range if provided', () => {
      const data = { coverage_percentage: 101 };
      const result = updateCoveragePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('coveragePlanIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = coveragePlanIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = coveragePlanIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = coveragePlanIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listCoveragePlansQuerySchema', () => {
    it('should validate correct query params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Test',
        provider_name: 'Provider',
        search: 'health',
        page: 1,
        limit: 20
      };
      const result = listCoveragePlansQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty query params', () => {
      const result = listCoveragePlansQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate tenant_id UUID format', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listCoveragePlansQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
