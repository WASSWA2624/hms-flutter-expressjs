/**
 * Lab QC log schema tests
 */

const {
  createLabQcLogSchema,
  updateLabQcLogSchema,
  labQcLogIdParamsSchema,
  listLabQcLogsQuerySchema
} = require('@validations/lab-qc-log/lab-qc-log.schema');

describe('Lab QC Log Schemas', () => {
  describe('createLabQcLogSchema', () => {
    const validData = {
      lab_test_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'Passed',
      notes: 'QC passed all checks',
      logged_at: '2024-01-01T10:00:00.000Z'
    };

    it('should validate correct lab QC log data', () => {
      const result = createLabQcLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require lab_test_id', () => {
      const data = { ...validData };
      delete data.lab_test_id;
      const result = createLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional notes', () => {
      const data = { ...validData };
      delete data.notes;
      const result = createLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional logged_at', () => {
      const data = { ...validData };
      delete data.logged_at;
      const result = createLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should enforce max length for status', () => {
      const data = { ...validData, status: 'a'.repeat(81) };
      const result = createLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null values for optional fields', () => {
      const data = {
        ...validData,
        status: null,
        notes: null
      };
      const result = createLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateLabQcLogSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateLabQcLogSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial update with status only', () => {
      const data = { status: 'Failed' };
      const result = updateLabQcLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('labQcLogIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = labQcLogIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = labQcLogIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listLabQcLogsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = { page: 1, limit: 20 };
      const result = listLabQcLogsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept lab_test_id filter', () => {
      const data = { lab_test_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listLabQcLogsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
