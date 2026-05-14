/**
 * Department schema validation tests
 *
 * @module tests/modules/department/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createDepartmentSchema,
  updateDepartmentSchema,
  departmentIdParamsSchema,
  listDepartmentsQuerySchema
} = require('@validations/department/department.schema');

describe('Department Schema Validation', () => {
  describe('createDepartmentSchema', () => {
    it('should validate correct department data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        branch_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      const result = createDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (tenant_id, name, and department_type only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null branch_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        branch_id: null,
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all department types', () => {
      const types = ['CLINICAL', 'ADMINISTRATIVE', 'SUPPORT', 'DIAGNOSTICS', 'OTHER'];
      types.forEach(type => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          name: `${type} Department`,
          department_type: type
        };
        const result = createDepartmentSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Emergency Department  ',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Emergency Department');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: 'not-a-uuid',
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid branch_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        branch_id: 'not-a-uuid',
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '',
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(256),
        department_type: 'CLINICAL'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing department_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Emergency Department'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Emergency Department',
        department_type: 'INVALID_TYPE'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: 'yes'
      };
      const result = createDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateDepartmentSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        branch_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Updated Department',
        department_type: 'ADMINISTRATIVE',
        is_active: false
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Department'
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only department_type', () => {
      const validData = {
        department_type: 'SUPPORT'
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only branch_id', () => {
      const validData = {
        branch_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: false
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        facility_id: null
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null branch_id', () => {
      const validData = {
        branch_id: null
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Department  '
      };
      const result = updateDepartmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Department');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = updateDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid branch_id UUID', () => {
      const invalidData = {
        branch_id: 'not-a-uuid'
      };
      const result = updateDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_type', () => {
      const invalidData = {
        department_type: 'INVALID_TYPE'
      };
      const result = updateDepartmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('departmentIdParamsSchema', () => {
    it('should validate correct UUID department ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = departmentIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = departmentIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = departmentIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = departmentIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listDepartmentsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with tenant_id filter', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with branch_id filter', () => {
      const validData = {
        branch_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with department_type filter', () => {
      const validData = {
        department_type: 'CLINICAL'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'emergency'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
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
        branch_id: '123e4567-e89b-12d3-a456-426614174002',
        department_type: 'CLINICAL',
        is_active: 'false',
        search: 'department'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid branch_id UUID', () => {
      const invalidData = {
        branch_id: 'not-a-uuid'
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_type', () => {
      const invalidData = {
        department_type: 'INVALID_TYPE'
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listDepartmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  department  '
      };
      const result = listDepartmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('department');
      }
    });
  });
});
