/**
 * Ward schema validation tests
 *
 * @module tests/modules/ward/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createWardSchema,
  updateWardSchema,
  wardIdParamsSchema,
  listWardsQuerySchema
} = require('@validations/ward/ward.schema');

describe('Ward Schema Validation', () => {
  describe('createWardSchema', () => {
    it('should validate correct ward data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        department_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      const result = createWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (required fields only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null department_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        department_id: null,
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all ward types', () => {
      const wardTypes = ['GENERAL', 'ICU', 'MATERNITY', 'PEDIATRIC', 'SURGICAL', 'OTHER'];
      wardTypes.forEach(wardType => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          facility_id: '123e4567-e89b-12d3-a456-426614174001',
          name: `${wardType} Ward`,
          ward_type: wardType
        };
        const result = createWardSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: '  ICU Ward  ',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('ICU Ward');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing facility_id', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: 'not-a-uuid',
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        department_id: 'not-a-uuid',
        name: 'ICU Ward',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: '',
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'a'.repeat(256),
        ward_type: 'ICU'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing ward_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'ICU Ward'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'ICU Ward',
        ward_type: 'INVALID_TYPE'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: 'yes'
      };
      const result = createWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateWardSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        department_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Updated Ward',
        ward_type: 'GENERAL',
        is_active: false
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Ward'
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only department_id', () => {
      const validData = {
        department_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only ward_type', () => {
      const validData = {
        ward_type: 'SURGICAL'
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: false
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null department_id', () => {
      const validData = {
        department_id: null
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Ward  '
      };
      const result = updateWardSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Ward');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = updateWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_id UUID', () => {
      const invalidData = {
        department_id: 'not-a-uuid'
      };
      const result = updateWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_type', () => {
      const invalidData = {
        ward_type: 'INVALID_TYPE'
      };
      const result = updateWardSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('wardIdParamsSchema', () => {
    it('should validate correct UUID ward ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = wardIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = wardIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = wardIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = wardIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listWardsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with tenant_id filter', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with department_id filter', () => {
      const validData = {
        department_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with ward_type filter', () => {
      const validData = {
        ward_type: 'ICU'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'icu'
      };
      const result = listWardsQuerySchema.safeParse(validData);
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
        department_id: '123e4567-e89b-12d3-a456-426614174002',
        ward_type: 'MATERNITY',
        is_active: 'false',
        search: 'ward'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_id UUID', () => {
      const invalidData = {
        department_id: 'not-a-uuid'
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_type', () => {
      const invalidData = {
        ward_type: 'INVALID_TYPE'
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listWardsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  ward  '
      };
      const result = listWardsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('ward');
      }
    });
  });
});
