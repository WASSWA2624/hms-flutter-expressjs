/**
 * ICU Stay schema tests
 *
 * @module tests/modules/icu-stay/schemas
 * @description Tests for ICU stay validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createIcuStaySchema,
  updateIcuStaySchema,
  icuStayIdParamsSchema,
  listIcuStaysQuerySchema
} = require('@validations/icu-stay/icu-stay.schema');

describe('ICU Stay Schemas', () => {
  describe('createIcuStaySchema', () => {
    const validData = {
      admission_id: '550e8400-e29b-41d4-a716-446655440000',
      started_at: '2024-01-01T10:00:00.000Z',
      ended_at: '2024-01-02T10:00:00.000Z'
    };

    it('should validate correct ICU stay data', () => {
      const result = createIcuStaySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require admission_id', () => {
      const data = { ...validData };
      delete data.admission_id;
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional started_at', () => {
      const data = { ...validData };
      delete data.started_at;
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional ended_at', () => {
      const data = { ...validData };
      delete data.ended_at;
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null ended_at', () => {
      const data = { ...validData, ended_at: null };
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate admission_id format', () => {
      const data = { ...validData, admission_id: 'invalid-uuid' };
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate started_at datetime format', () => {
      const data = { ...validData, started_at: 'invalid-date' };
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate ended_at datetime format', () => {
      const data = { ...validData, ended_at: 'invalid-date' };
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid ISO 8601 datetime for started_at', () => {
      const data = { ...validData, started_at: '2024-01-15T14:30:00.000Z' };
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid ISO 8601 datetime for ended_at', () => {
      const data = { ...validData, ended_at: '2024-01-20T18:45:00.000Z' };
      const result = createIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateIcuStaySchema', () => {
    it('should validate with all fields', () => {
      const data = {
        started_at: '2024-01-01T10:00:00.000Z',
        ended_at: '2024-01-02T10:00:00.000Z'
      };
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only started_at', () => {
      const data = { started_at: '2024-01-01T10:00:00.000Z' };
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only ended_at', () => {
      const data = { ended_at: '2024-01-02T10:00:00.000Z' };
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const data = {};
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null ended_at', () => {
      const data = { ended_at: null };
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate started_at datetime format', () => {
      const data = { started_at: 'invalid-date' };
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate ended_at datetime format', () => {
      const data = { ended_at: 'invalid-date' };
      const result = updateIcuStaySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('icuStayIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = icuStayIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = icuStayIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const data = {};
      const result = icuStayIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listIcuStaysQuerySchema', () => {
    it('should validate with no filters', () => {
      const data = {};
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with admission_id filter', () => {
      const data = { admission_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with date range filters', () => {
      const data = {
        started_at_from: '2024-01-01T00:00:00.000Z',
        started_at_to: '2024-01-31T23:59:59.999Z'
      };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with ended_at range filters', () => {
      const data = {
        ended_at_from: '2024-01-01T00:00:00.000Z',
        ended_at_to: '2024-01-31T23:59:59.999Z'
      };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const data = { is_active: 'true' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_active).toBe(true);
      }
    });

    it('should transform is_active string to boolean', () => {
      const data = { is_active: 'false' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_active).toBe(false);
      }
    });

    it('should validate with pagination parameters', () => {
      const data = { page: '2', limit: '50' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with sort parameters', () => {
      const data = { sort_by: 'started_at', order: 'desc' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all parameters combined', () => {
      const data = {
        admission_id: '550e8400-e29b-41d4-a716-446655440000',
        started_at_from: '2024-01-01T00:00:00.000Z',
        started_at_to: '2024-01-31T23:59:59.999Z',
        is_active: 'true',
        page: '1',
        limit: '20',
        sort_by: 'started_at',
        order: 'asc'
      };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid admission_id UUID', () => {
      const data = { admission_id: 'invalid-uuid' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid started_at_from datetime', () => {
      const data = { started_at_from: 'invalid-date' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ended_at_to datetime', () => {
      const data = { ended_at_to: 'not-a-date' };
      const result = listIcuStaysQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
