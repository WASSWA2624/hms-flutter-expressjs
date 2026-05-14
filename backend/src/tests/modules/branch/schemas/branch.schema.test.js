/**
 * Branch schema validation tests
 *
 * @module tests/modules/branch/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createBranchSchema,
  updateBranchSchema,
  branchIdParamsSchema,
  listBranchesQuerySchema
} = require('@validations/branch/branch.schema');

describe('Branch Schema Validation', () => {
  describe('createBranchSchema', () => {
    it('should validate correct branch data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Main Branch',
        is_active: true
      };
      const result = createBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (tenant_id and name only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Main Branch'
      };
      const result = createBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'Main Branch'
      };
      const result = createBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Main Branch  '
      };
      const result = createBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Main Branch');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        name: 'Main Branch'
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        name: 'Main Branch'
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: 'not-a-uuid',
        name: 'Main Branch'
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: ''
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(256)
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Main Branch',
        is_active: 'yes'
      };
      const result = createBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateBranchSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Updated Branch',
        is_active: false
      };
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Branch'
      };
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: false
      };
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        facility_id: null
      };
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Branch  '
      };
      const result = updateBranchSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Branch');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = updateBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateBranchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('branchIdParamsSchema', () => {
    it('should validate correct UUID branch ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = branchIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = branchIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = branchIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = branchIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listBranchesQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with tenant_id filter', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'main'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'name',
        order: 'asc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        is_active: 'false',
        search: 'branch'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listBranchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listBranchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listBranchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listBranchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listBranchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listBranchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  branch  '
      };
      const result = listBranchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('branch');
      }
    });
  });
});
