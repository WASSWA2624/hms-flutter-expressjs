/**
 * Lab panel schema validation tests
 *
 * @module tests/modules/lab-panel/schemas
 * @description Tests for lab panel validation schemas
 * Per testing.mdc: All validation schemas must be tested
 */

const {
  createLabPanelSchema,
  updateLabPanelSchema,
  labPanelIdParamsSchema,
  listLabPanelsQuerySchema
} = require('@validations/lab-panel/lab-panel.schema');

describe('Lab Panel Schema Validation', () => {
  describe('createLabPanelSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel',
        code: 'CMP',
        panel_items: [
          {
            lab_test_id: 'LBT0000001',
            is_required: true,
            instructions: 'Collect fasting sample',
          },
        ],
      };

      const result = createLabPanelSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate create data without optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel'
      };

      const result = createLabPanelSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation when tenant_id is missing', () => {
      const invalidData = {
        name: 'Complete Metabolic Panel'
      };

      const result = createLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when name is missing', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when name is empty', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: ''
      };

      const result = createLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when name exceeds max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'A'.repeat(256)
      };

      const result = createLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when tenant_id is invalid UUID', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Complete Metabolic Panel'
      };

      const result = createLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from string fields', () => {
      const dataWithWhitespace = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Complete Metabolic Panel  ',
        code: '  CMP  '
      };

      const result = createLabPanelSchema.safeParse(dataWithWhitespace);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Complete Metabolic Panel');
        expect(result.data.code).toBe('CMP');
      }
    });

    it('should fail validation when code exceeds max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel',
        code: 'A'.repeat(81)
      };

      const result = createLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateLabPanelSchema', () => {
    it('should validate correct update data with all fields', () => {
      const validData = {
        name: 'Updated Lab Panel',
        code: 'ULP',
        panel_items: [
          {
            lab_test_id: 'LBT0000002',
            is_required: false,
          },
        ],
      };

      const result = updateLabPanelSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate update data with partial fields', () => {
      const validData = {
        name: 'Updated Lab Panel'
      };

      const result = updateLabPanelSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update object', () => {
      const validData = {};

      const result = updateLabPanelSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation when name is empty string', () => {
      const invalidData = {
        name: ''
      };

      const result = updateLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation when name exceeds max length', () => {
      const invalidData = {
        name: 'A'.repeat(256)
      };

      const result = updateLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from string fields', () => {
      const dataWithWhitespace = {
        name: '  Updated Lab Panel  ',
        code: '  ULP  '
      };

      const result = updateLabPanelSchema.safeParse(dataWithWhitespace);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Lab Panel');
        expect(result.data.code).toBe('ULP');
      }
    });

    it('should fail validation when the same lab test appears twice in a panel', () => {
      const invalidData = {
        panel_items: [
          { lab_test_id: 'LBT0000001' },
          { lab_test_id: 'LBT0000001' },
        ],
      };

      const result = updateLabPanelSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('labPanelIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validParams = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = labPanelIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });

    it('should fail validation for invalid UUID', () => {
      const invalidParams = {
        id: 'invalid-uuid'
      };

      const result = labPanelIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });

    it('should fail validation when id is missing', () => {
      const invalidParams = {};

      const result = labPanelIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });

    it('should fail validation for empty string id', () => {
      const invalidParams = {
        id: ''
      };

      const result = labPanelIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });
  });

  describe('listLabPanelsQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const validQuery = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel',
        code: 'CMP',
        search: 'metabolic',
        page: '1',
        limit: '20',
        sort_by: 'name',
        order: 'asc'
      };

      const result = listLabPanelsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should validate query with only pagination params', () => {
      const validQuery = {
        page: '1',
        limit: '20'
      };

      const result = listLabPanelsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should validate empty query', () => {
      const validQuery = {};

      const result = listLabPanelsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should fail validation when tenant_id is invalid UUID', () => {
      const invalidQuery = {
        tenant_id: 'invalid-uuid'
      };

      const result = listLabPanelsQuerySchema.safeParse(invalidQuery);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from string fields', () => {
      const queryWithWhitespace = {
        name: '  Complete Metabolic Panel  ',
        code: '  CMP  ',
        search: '  metabolic  '
      };

      const result = listLabPanelsQuerySchema.safeParse(queryWithWhitespace);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Complete Metabolic Panel');
        expect(result.data.code).toBe('CMP');
        expect(result.data.search).toBe('metabolic');
      }
    });

    it('should validate query with sort parameters', () => {
      const validQuery = {
        sort_by: 'created_at',
        order: 'desc'
      };

      const result = listLabPanelsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });
  });
});
