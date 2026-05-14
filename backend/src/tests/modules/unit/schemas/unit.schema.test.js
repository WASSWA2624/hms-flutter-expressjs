/**
 * Unit schema validation tests
 *
 * @module tests/modules/unit/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createUnitSchema,
  updateUnitSchema,
  unitIdParamsSchema,
  listUnitsQuerySchema
} = require('@validations/unit/unit.schema');

describe('Unit Schema Validation', () => {
  describe('createUnitSchema', () => {
    it('should validate correct unit data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        department_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'ICU Unit',
        is_active: true
      };
      const result = createUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (tenant_id and name only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null department_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        department_id: null,
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  ICU Unit  '
      };
      const result = createUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('ICU Unit');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: 'not-a-uuid',
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        department_id: 'not-a-uuid',
        name: 'ICU Unit'
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: ''
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(256)
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'ICU Unit',
        is_active: 'yes'
      };
      const result = createUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateUnitSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        department_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Updated Unit',
        is_active: false
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Unit'
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only department_id', () => {
      const validData = {
        department_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: false
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        facility_id: null
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null department_id', () => {
      const validData = {
        department_id: null
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Unit  '
      };
      const result = updateUnitSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Unit');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = updateUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_id UUID', () => {
      const invalidData = {
        department_id: 'not-a-uuid'
      };
      const result = updateUnitSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('unitIdParamsSchema', () => {
    it('should validate correct UUID unit ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = unitIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = unitIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = unitIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = unitIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listUnitsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with tenant_id filter', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with department_id filter', () => {
      const validData = {
        department_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'icu'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
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
        is_active: 'false',
        search: 'unit'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid department_id UUID', () => {
      const invalidData = {
        department_id: 'not-a-uuid'
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listUnitsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  unit  '
      };
      const result = listUnitsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('unit');
      }
    });
  });
});
