/**
 * Radiology Result schema tests
 *
 * @module tests/modules/radiology-result/schemas
 * @description Tests for radiology result validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createRadiologyResultSchema,
  updateRadiologyResultSchema,
  radiologyResultIdParamsSchema,
  listRadiologyResultsQuerySchema
} = require('@validations/radiology-result/radiology-result.schema');

describe('Radiology Result Schemas', () => {
  describe('createRadiologyResultSchema', () => {
    const validData = {
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'DRAFT',
      report_text: 'Preliminary findings show normal results.',
      reported_at: '2026-01-19T14:30:00.000Z'
    };

    it('should validate correct radiology result data', () => {
      const result = createRadiologyResultSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require radiology_order_id', () => {
      const data = { ...validData };
      delete data.radiology_order_id;
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['DRAFT', 'FINAL', 'AMENDED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createRadiologyResultSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional report_text', () => {
      const data = { ...validData };
      delete data.report_text;
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional reported_at', () => {
      const data = { ...validData };
      delete data.reported_at;
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null report_text', () => {
      const data = { ...validData, report_text: null };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null reported_at', () => {
      const data = { ...validData, reported_at: null };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for radiology_order_id', () => {
      const data = { ...validData, radiology_order_id: 'invalid-uuid' };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for reported_at', () => {
      const data = { ...validData, reported_at: 'not-a-datetime' };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid datetime for reported_at', () => {
      const data = { ...validData, reported_at: '2026-12-31T23:59:59.999Z' };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim report_text', () => {
      const data = { ...validData, report_text: '  Findings with spaces  ' };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.report_text).toBe('Findings with spaces');
      }
    });

    it('should enforce max length on report_text', () => {
      const data = { ...validData, report_text: 'a'.repeat(65536) };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept report_text at max length', () => {
      const data = { ...validData, report_text: 'a'.repeat(65535) };
      const result = createRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateRadiologyResultSchema', () => {
    const validData = {
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'FINAL',
      report_text: 'Final report with conclusive findings.',
      reported_at: '2026-01-19T16:00:00.000Z'
    };

    it('should validate correct update data', () => {
      const result = updateRadiologyResultSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow empty object (no updates)', () => {
      const result = updateRadiologyResultSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only status', () => {
      const data = { status: 'AMENDED' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only radiology_order_id', () => {
      const data = { radiology_order_id: '550e8400-e29b-41d4-a716-446655440005' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only report_text', () => {
      const data = { report_text: 'Updated report text' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only reported_at', () => {
      const data = { reported_at: '2026-01-20T10:00:00.000Z' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum values', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values', () => {
      const statuses = ['DRAFT', 'FINAL', 'AMENDED'];
      statuses.forEach(status => {
        const data = { status };
        const result = updateRadiologyResultSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow null report_text', () => {
      const data = { report_text: null };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null reported_at', () => {
      const data = { reported_at: null };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for radiology_order_id', () => {
      const data = { radiology_order_id: 'not-a-uuid' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for reported_at', () => {
      const data = { reported_at: 'invalid-date' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim report_text', () => {
      const data = { report_text: '  Trimmed text  ' };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.report_text).toBe('Trimmed text');
      }
    });

    it('should enforce max length on report_text', () => {
      const data = { report_text: 'a'.repeat(65536) };
      const result = updateRadiologyResultSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('radiologyResultIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = radiologyResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'not-a-uuid' };
      const result = radiologyResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = radiologyResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject null id', () => {
      const data = { id: null };
      const result = radiologyResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty string id', () => {
      const data = { id: '' };
      const result = radiologyResultIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listRadiologyResultsQuerySchema', () => {
    it('should validate empty query', () => {
      const result = listRadiologyResultsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with sort params', () => {
      const data = { sort_by: 'reported_at', order: 'desc' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all filter params', () => {
      const data = {
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'FINAL',
        search: 'test search',
        page: '2',
        limit: '50',
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum values', () => {
      const data = { status: 'DRAFT' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status values', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values', () => {
      const statuses = ['DRAFT', 'FINAL', 'AMENDED'];
      statuses.forEach(status => {
        const data = { status };
        const result = listRadiologyResultsQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate search param', () => {
      const data = { search: 'MRI scan findings' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim search param', () => {
      const data = { search: '  spaced search  ' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('spaced search');
      }
    });

    it('should reject invalid UUID for radiology_order_id', () => {
      const data = { radiology_order_id: 'invalid-uuid' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate order param values', () => {
      const validOrders = ['asc', 'desc'];
      validOrders.forEach(order => {
        const data = { order };
        const result = listRadiologyResultsQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid order values', () => {
      const data = { order: 'invalid' };
      const result = listRadiologyResultsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
