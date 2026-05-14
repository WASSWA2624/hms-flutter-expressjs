/**
 * Module schema validation tests
 *
 * @module tests/modules/module/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createModuleSchema,
  updateModuleSchema,
  moduleIdParamsSchema,
  listModulesQuerySchema
} = require('@validations/module/module.schema');

describe('Module Schema Validation', () => {
  describe('createModuleSchema', () => {
    it('should validate correct module data', () => {
      const validData = {
        name: 'Test Module',
        slug: 'test-module',
        description: 'Test module description',
        module_group: 'Operations',
        minimum_plan_tier_code: 'PRO',
        is_add_on: true,
        add_on_price: 25,
        add_on_billing_cycle: 'MONTHLY',
        entitlement_policy_json: {
          allowed_plan_ids: ['PLAN-PRO']
        }
      };
      const result = createModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (name only)', () => {
      const validData = {
        name: 'Test Module'
      };
      const result = createModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Test Module  '
      };
      const result = createModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Test Module');
      }
    });

    it('should trim description whitespace', () => {
      const validData = {
        name: 'Test Module',
        description: '  Test description  '
      };
      const result = createModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.description).toBe('Test description');
      }
    });

    it('should accept null description', () => {
      const validData = {
        name: 'Test Module',
        description: null
      };
      const result = createModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept undefined description', () => {
      const validData = {
        name: 'Test Module',
        description: undefined
      };
      const result = createModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing name', () => {
      const invalidData = {};
      const result = createModuleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = createModuleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 120 characters', () => {
      const invalidData = {
        name: 'a'.repeat(121)
      };
      const result = createModuleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateModuleSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        name: 'Updated Module',
        description: 'Updated description',
        entitlement_policy_json: {
          blocked_plan_ids: ['PLAN-BASIC']
        },
        extension_json: {
          rollout_notes: 'Custom rollout'
        }
      };
      const result = updateModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Module'
      };
      const result = updateModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only description', () => {
      const validData = {
        description: 'Updated description'
      };
      const result = updateModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null description', () => {
      const validData = {
        description: null
      };
      const result = updateModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Module  '
      };
      const result = updateModuleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Module');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateModuleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 120 characters', () => {
      const invalidData = {
        name: 'a'.repeat(121)
      };
      const result = updateModuleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative add-on pricing', () => {
      const invalidData = {
        add_on_price: -5
      };
      const result = updateModuleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('moduleIdParamsSchema', () => {
    it('should validate correct UUID module ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = moduleIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = moduleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = moduleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = moduleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listModulesQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'patient'
      };
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'name',
        order: 'asc',
        search: 'billing'
      };
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listModulesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listModulesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listModulesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  module  '
      };
      const result = listModulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('module');
      }
    });
  });
});
