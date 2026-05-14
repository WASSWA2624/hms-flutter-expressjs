/**
 * Discharge summary schema tests
 *
 * @module tests/modules/discharge-summary/schemas
 * @description Tests for discharge summary validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createDischargeSummarySchema,
  updateDischargeSummarySchema,
  dischargeSummaryIdParamsSchema,
  listDischargeSummariesQuerySchema
} = require('@validations/discharge-summary/discharge-summary.schema');

describe('Discharge Summary Schemas', () => {
  describe('createDischargeSummarySchema', () => {
    const validData = {
      admission_id: '550e8400-e29b-41d4-a716-446655440000',
      summary: 'Patient recovered well. Discharged with medications.',
      status: 'COMPLETED'
    };

    it('should validate correct discharge summary data', () => {
      const result = createDischargeSummarySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require admission_id', () => {
      const data = { ...validData };
      delete data.admission_id;
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require summary', () => {
      const data = { ...validData };
      delete data.summary;
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const validStatuses = ['PLANNED', 'COMPLETED', 'CANCELLED'];
      
      validStatuses.forEach(status => {
        const data = { ...validData, status };
        const result = createDischargeSummarySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid status enum', () => {
      const data = { ...validData, status: 'INVALID_STATUS' };
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional discharged_at', () => {
      const data = {
        ...validData,
        discharged_at: '2024-01-01T10:00:00Z'
      };
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for admission_id', () => {
      const data = { ...validData, admission_id: 'invalid-uuid' };
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty summary', () => {
      const data = { ...validData, summary: '' };
      const result = createDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateDischargeSummarySchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateDischargeSummarySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = { summary: 'Updated summary', status: 'COMPLETED' };
      const result = updateDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum in update', () => {
      const data = { status: 'CANCELLED' };
      const result = updateDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status enum in update', () => {
      const data = { status: 'INVALID' };
      const result = updateDischargeSummarySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('dischargeSummaryIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = dischargeSummaryIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = dischargeSummaryIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listDischargeSummariesQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listDischargeSummariesQuerySchema.safeParse({
        page: '1',
        limit: '20',
        admission_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'COMPLETED'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listDischargeSummariesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should reject invalid status filter', () => {
      const result = listDischargeSummariesQuerySchema.safeParse({
        status: 'INVALID'
      });
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for admission_id filter', () => {
      const result = listDischargeSummariesQuerySchema.safeParse({
        admission_id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });
});
