/**
 * Lab sample schema tests
 *
 * @module tests/modules/lab-sample/schemas
 * @description Tests for lab sample validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createLabSampleSchema,
  updateLabSampleSchema,
  labSampleIdParamsSchema,
  listLabSamplesQuerySchema
} = require('@validations/lab-sample/lab-sample.schema');

describe('Lab Sample Schemas', () => {
  describe('createLabSampleSchema', () => {
    const validData = {
      lab_order_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'PENDING',
      collected_at: '2024-01-01T10:00:00.000Z',
      received_at: '2024-01-01T12:00:00.000Z'
    };

    it('should validate correct lab sample data', () => {
      const result = createLabSampleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require lab_order_id', () => {
      const data = { ...validData };
      delete data.lab_order_id;
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum - PENDING', () => {
      const data = { ...validData, status: 'PENDING' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - COLLECTED', () => {
      const data = { ...validData, status: 'COLLECTED' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - REJECTED', () => {
      const data = { ...validData, status: 'REJECTED' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - RECEIVED', () => {
      const data = { ...validData, status: 'RECEIVED' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status enum', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional collected_at', () => {
      const data = { ...validData };
      delete data.collected_at;
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional received_at', () => {
      const data = { ...validData };
      delete data.received_at;
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null collected_at', () => {
      const data = { ...validData, collected_at: null };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null received_at', () => {
      const data = { ...validData, received_at: null };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate datetime format for collected_at', () => {
      const data = { ...validData, collected_at: 'invalid-date' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for received_at', () => {
      const data = { ...validData, received_at: 'invalid-date' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid lab_order_id UUID', () => {
      const data = { ...validData, lab_order_id: 'invalid-uuid' };
      const result = createLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateLabSampleSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateLabSampleSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial update with status only', () => {
      const data = { status: 'COLLECTED' };
      const result = updateLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate partial update with collected_at only', () => {
      const data = { collected_at: '2024-01-01T10:00:00.000Z' };
      const result = updateLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate partial update with received_at only', () => {
      const data = { received_at: '2024-01-01T12:00:00.000Z' };
      const result = updateLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum when provided', () => {
      const data = { status: 'INVALID' };
      const result = updateLabSampleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for optional fields', () => {
      const data = {
        collected_at: null,
        received_at: null
      };
      const result = updateLabSampleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('labSampleIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = labSampleIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = labSampleIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = labSampleIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listLabSamplesQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listLabSamplesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filter params', () => {
      const data = {
        lab_order_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING'
      };
      const result = listLabSamplesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum in query', () => {
      const data = { status: 'INVALID' };
      const result = listLabSamplesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate lab_order_id UUID format', () => {
      const data = { lab_order_id: 'invalid-uuid' };
      const result = listLabSamplesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values in query', () => {
      const statuses = ['PENDING', 'COLLECTED', 'REJECTED', 'RECEIVED'];
      statuses.forEach(status => {
        const data = { status };
        const result = listLabSamplesQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });
  });
});
