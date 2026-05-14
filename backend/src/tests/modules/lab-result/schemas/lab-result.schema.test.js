/**
 * Lab result schema tests
 *
 * @module tests/modules/lab-result/schemas
 * @description Tests for lab result validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createLabResultSchema,
  updateLabResultSchema,
  labResultIdParamsSchema,
  listLabResultsQuerySchema
} = require('@validations/lab-result/lab-result.schema');

describe('Lab Result Schemas', () => {
  describe('createLabResultSchema', () => {
    const validData = {
      lab_order_item_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'PENDING',
      result_value: '98.6',
      result_unit: 'mg/dL',
      result_text: 'Normal range',
      reported_at: '2024-01-01T10:00:00.000Z'
    };

    it('should validate correct lab result data', () => {
      const result = createLabResultSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require lab_order_item_id', () => {
      const data = { ...validData };
      delete data.lab_order_item_id;
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow status to be omitted', () => {
      const data = { ...validData };
      delete data.status;
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - NORMAL', () => {
      const data = { ...validData, status: 'NORMAL' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - ABNORMAL', () => {
      const data = { ...validData, status: 'ABNORMAL' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - CRITICAL', () => {
      const data = { ...validData, status: 'CRITICAL' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - PENDING', () => {
      const data = { ...validData, status: 'PENDING' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status enum', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional result_value', () => {
      const data = { ...validData };
      delete data.result_value;
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional result_unit', () => {
      const data = { ...validData };
      delete data.result_unit;
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional result_text', () => {
      const data = { ...validData };
      delete data.result_text;
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional reported_at', () => {
      const data = { ...validData };
      delete data.reported_at;
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null values for optional fields', () => {
      const data = {
        ...validData,
        result_value: null,
        result_unit: null,
        result_text: null,
        reported_at: null
      };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should enforce max length for result_value', () => {
      const data = { ...validData, result_value: 'a'.repeat(121) };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for result_unit', () => {
      const data = { ...validData, result_unit: 'a'.repeat(41) };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string fields', () => {
      const data = {
        ...validData,
        result_value: '  98.6  ',
        result_unit: '  mg/dL  '
      };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.result_value).toBe('98.6');
        expect(result.data.result_unit).toBe('mg/dL');
      }
    });

    it('should validate datetime format for reported_at', () => {
      const data = { ...validData, reported_at: 'invalid-date' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid lab_order_item_id UUID', () => {
      const data = { ...validData, lab_order_item_id: 'invalid-uuid' };
      const result = createLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateLabResultSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateLabResultSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial update with status only', () => {
      const data = { status: 'NORMAL' };
      const result = updateLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate partial update with result_value only', () => {
      const data = { result_value: '100' };
      const result = updateLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum when provided', () => {
      const data = { status: 'INVALID' };
      const result = updateLabResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for optional fields', () => {
      const data = {
        result_value: null,
        result_unit: null,
        result_text: null,
        reported_at: null
      };
      const result = updateLabResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('labResultIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = labResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = labResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = labResultIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listLabResultsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listLabResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filter params', () => {
      const data = {
        lab_order_item_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'NORMAL'
      };
      const result = listLabResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum in query', () => {
      const data = { status: 'INVALID' };
      const result = listLabResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate lab_order_item_id UUID format', () => {
      const data = { lab_order_item_id: 'invalid-uuid' };
      const result = listLabResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values in query', () => {
      const statuses = ['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING'];
      statuses.forEach(status => {
        const data = { status };
        const result = listLabResultsQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });
  });
});
