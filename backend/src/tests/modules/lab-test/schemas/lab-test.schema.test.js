/**
 * Lab test schema validation tests
 *
 * @module tests/modules/lab-test/schemas
 * @description Tests for lab test validation schemas
 * Per testing.mdc: All validation schemas must be tested
 */

const {
  createLabTestSchema,
  updateLabTestSchema,
  labTestIdParamsSchema,
  listLabTestsQuerySchema
} = require('@validations/lab-test/lab-test.schema');

describe('Lab Test Schema Validation', () => {
  describe('createLabTestSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        code: 'CBC',
        category: 'Hematology',
        specimen_type: 'Whole blood',
        result_kind: 'QUALITATIVE',
        unit: 'cells/mcL',
        description: 'Demo lab test',
        reference_range: '4,500-11,000',
        unit_options: [
          {
            label: 'Default',
            unit: 'cells/mcL',
            ucum_code: '10*3/uL',
            is_default: true,
          },
        ],
        reference_ranges: [
          {
            label: 'Adult',
            unit: 'cells/mcL',
            gender: 'MALE',
            age_min_value: '18',
            age_min_unit: 'YEAR',
            normal_min_value: '4.5',
            normal_max_value: '11.0',
          },
        ],
        result_options: [
          {
            value: 'POSITIVE',
            label: 'Positive',
            aliases: ['Reactive'],
            status: 'ABNORMAL',
            result_flag: 'POSITIVE',
            is_positive: true,
          },
        ],
      };

      const result = createLabTestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate create data without optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count'
      };

      const result = createLabTestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation when tenant_id is missing', () => {
      const invalidData = {
        name: 'Complete Blood Count'
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      expect(result.error.issues).toBeDefined();
    });

    it('should fail validation when name is missing', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      expect(result.error.issues).toBeDefined();
    });

    it('should fail validation when name is empty', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: ''
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when name exceeds max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'A'.repeat(256)
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when tenant_id is invalid UUID', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Complete Blood Count'
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from string fields', () => {
      const dataWithWhitespace = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Complete Blood Count  ',
        code: '  CBC  '
      };

      const result = createLabTestSchema.safeParse(dataWithWhitespace);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Complete Blood Count');
        expect(result.data.code).toBe('CBC');
      }
    });

    it('should fail validation when code exceeds max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        code: 'A'.repeat(81)
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when unit exceeds max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        unit: 'A'.repeat(41)
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when reference_range exceeds max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        reference_range: 'A'.repeat(256)
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when structured ranges contain mismatched age value and unit', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        reference_ranges: [
          {
            age_min_value: '18',
          },
        ],
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when unit options contain duplicates', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        unit_options: [
          { unit: 'g/dL' },
          { unit: 'g/dL' },
        ],
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when qualitative result options contain duplicates', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Malaria Rapid Antigen',
        result_kind: 'QUALITATIVE',
        result_options: [
          { value: 'POSITIVE' },
          { value: 'POSITIVE' },
        ],
      };

      const result = createLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateLabTestSchema', () => {
    it('should validate correct update data with all fields', () => {
      const validData = {
        name: 'Updated Lab Test',
        code: 'ULT',
        unit: 'mg/dL',
        reference_range: '0-100',
        reference_ranges: [
          {
            label: 'Pediatric',
            age_max_value: '12',
            age_max_unit: 'YEAR',
            normal_min_value: '3.5',
            normal_max_value: '10.5',
          },
        ],
      };

      const result = updateLabTestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate update data with partial fields', () => {
      const validData = {
        name: 'Updated Lab Test'
      };

      const result = updateLabTestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update object', () => {
      const validData = {};

      const result = updateLabTestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation when name is empty string', () => {
      const invalidData = {
        name: ''
      };

      const result = updateLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when name exceeds max length', () => {
      const invalidData = {
        name: 'A'.repeat(256)
      };

      const result = updateLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from string fields', () => {
      const dataWithWhitespace = {
        name: '  Updated Lab Test  ',
        code: '  ULT  '
      };

      const result = updateLabTestSchema.safeParse(dataWithWhitespace);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Lab Test');
        expect(result.data.code).toBe('ULT');
      }
    });

    it('should fail validation when the normal range minimum exceeds the maximum', () => {
      const invalidData = {
        reference_ranges: [
          {
            normal_min_value: '20',
            normal_max_value: '10',
          },
        ],
      };

      const result = updateLabTestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('labTestIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validParams = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = labTestIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });

    it('should fail validation for invalid UUID', () => {
      const invalidParams = {
        id: 'invalid-uuid'
      };

      const result = labTestIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });

    it('should fail validation when id is missing', () => {
      const invalidParams = {};

      const result = labTestIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });

    it('should fail validation for empty string id', () => {
      const invalidParams = {
        id: ''
      };

      const result = labTestIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });
  });

  describe('listLabTestsQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const validQuery = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        code: 'CBC',
        search: 'blood',
        page: '1',
        limit: '20',
        sort_by: 'name',
        order: 'asc'
      };

      const result = listLabTestsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should validate query with only pagination params', () => {
      const validQuery = {
        page: '1',
        limit: '20'
      };

      const result = listLabTestsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should validate empty query', () => {
      const validQuery = {};

      const result = listLabTestsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should fail validation when tenant_id is invalid UUID', () => {
      const invalidQuery = {
        tenant_id: 'invalid-uuid'
      };

      const result = listLabTestsQuerySchema.safeParse(invalidQuery);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from string fields', () => {
      const queryWithWhitespace = {
        name: '  Complete Blood Count  ',
        code: '  CBC  ',
        search: '  blood  '
      };

      const result = listLabTestsQuerySchema.safeParse(queryWithWhitespace);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Complete Blood Count');
        expect(result.data.code).toBe('CBC');
        expect(result.data.search).toBe('blood');
      }
    });

    it('should validate query with sort parameters', () => {
      const validQuery = {
        sort_by: 'created_at',
        order: 'desc'
      };

      const result = listLabTestsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should parse include_standard_catalog as a boolean query flag', () => {
      const result = listLabTestsQuerySchema.safeParse({
        include_standard_catalog: 'true'
      });

      expect(result.success).toBe(true);
      expect(result.data.include_standard_catalog).toBe(true);
    });

    it('should preserve false include_standard_catalog query flag', () => {
      const result = listLabTestsQuerySchema.safeParse({
        include_standard_catalog: 'false'
      });

      expect(result.success).toBe(true);
      expect(result.data.include_standard_catalog).toBe(false);
    });
  });
});
