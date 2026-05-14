/**
 * System change log schema tests
 *
 * @module tests/modules/system-change-log/schemas
 * @description Tests for system change log validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createSystemChangeLogSchema,
  updateSystemChangeLogSchema,
  approveSystemChangeLogSchema,
  implementSystemChangeLogSchema,
  systemChangeLogIdParamsSchema,
  listSystemChangeLogsQuerySchema
} = require('@validations/system-change-log/system-change-log.schema');

describe('System Change Log Schemas', () => {
  describe('createSystemChangeLogSchema', () => {
    const validData = {
      change_type: 'DATABASE_MIGRATION',
      details: 'Added new column to users table'
    };

    it('should validate correct system change log data', () => {
      const result = createSystemChangeLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require change_type', () => {
      const data = { ...validData };
      delete data.change_type;
      const result = createSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce change_type max length of 120', () => {
      const data = { ...validData, change_type: 'A'.repeat(121) };
      const result = createSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce change_type min length of 1', () => {
      const data = { ...validData, change_type: '' };
      const result = createSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional details', () => {
      const data = { ...validData };
      delete data.details;
      const result = createSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable details', () => {
      const data = { ...validData, details: null };
      const result = createSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim change_type', () => {
      const data = { ...validData, change_type: '  DATABASE_MIGRATION  ' };
      const result = createSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.change_type).toBe('DATABASE_MIGRATION');
      }
    });
  });

  describe('updateSystemChangeLogSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        change_type: 'CONFIG_UPDATE',
        details: 'Updated system configuration'
      };
      const result = updateSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { change_type: 'SECURITY_PATCH' };
      const result = updateSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update object', () => {
      const data = {};
      const result = updateSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should enforce change_type max length when provided', () => {
      const data = { change_type: 'A'.repeat(121) };
      const result = updateSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow nullable details', () => {
      const data = { details: null };
      const result = updateSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('approveSystemChangeLogSchema', () => {
    it('should validate approve with approval_notes', () => {
      const data = { approval_notes: 'Approved after review' };
      const result = approveSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional approval_notes', () => {
      const data = {};
      const result = approveSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable approval_notes', () => {
      const data = { approval_notes: null };
      const result = approveSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('implementSystemChangeLogSchema', () => {
    it('should validate implement with implementation_notes', () => {
      const data = { implementation_notes: 'Successfully implemented' };
      const result = implementSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional implementation_notes', () => {
      const data = {};
      const result = implementSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable implementation_notes', () => {
      const data = { implementation_notes: null };
      const result = implementSystemChangeLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('systemChangeLogIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = systemChangeLogIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = systemChangeLogIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listSystemChangeLogsQuerySchema', () => {
    it('should validate query with all optional filters', () => {
      const query = {
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        change_type: 'DATABASE_MIGRATION',
        from_date: '2024-01-01T00:00:00Z',
        to_date: '2024-01-31T23:59:59Z',
        page: 1,
        limit: 20
      };
      const result = listSystemChangeLogsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate query with no filters', () => {
      const query = {};
      const result = listSystemChangeLogsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate user_id format', () => {
      const query = { user_id: 'invalid-uuid' };
      const result = listSystemChangeLogsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate from_date format', () => {
      const query = { from_date: 'invalid-date' };
      const result = listSystemChangeLogsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate to_date format', () => {
      const query = { to_date: 'invalid-date' };
      const result = listSystemChangeLogsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });
  });
});
