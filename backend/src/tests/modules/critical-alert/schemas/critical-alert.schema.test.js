/**
 * Critical Alert schema tests
 *
 * @module tests/modules/critical-alert/schemas
 * @description Tests for critical alert validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createCriticalAlertSchema,
  updateCriticalAlertSchema,
  criticalAlertIdParamsSchema,
  listCriticalAlertsQuerySchema
} = require('@validations/critical-alert/critical-alert.schema');

describe('Critical Alert Schemas', () => {
  describe('createCriticalAlertSchema', () => {
    const validData = {
      icu_stay_id: '550e8400-e29b-41d4-a716-446655440000',
      severity: 'CRITICAL',
      message: 'Patient heart rate dropping rapidly'
    };

    it('should validate correct critical alert data', () => {
      const result = createCriticalAlertSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require icu_stay_id', () => {
      const data = { ...validData };
      delete data.icu_stay_id;
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require severity', () => {
      const data = { ...validData };
      delete data.severity;
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require message', () => {
      const data = { ...validData };
      delete data.message;
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate all severity values', () => {
      ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].forEach(severity => {
        const data = { ...validData, severity };
        const result = createCriticalAlertSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid severity', () => {
      const data = { ...validData, severity: 'INVALID' };
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate icu_stay_id format', () => {
      const data = { ...validData, icu_stay_id: 'invalid-uuid' };
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim message text', () => {
      const data = { ...validData, message: '  Test alert  ' };
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.message).toBe('Test alert');
      }
    });

    it('should enforce min length for message', () => {
      const data = { ...validData, message: '' };
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for message', () => {
      const data = { ...validData, message: 'a'.repeat(2001) };
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept max length of 2000 chars', () => {
      const data = { ...validData, message: 'a'.repeat(2000) };
      const result = createCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateCriticalAlertSchema', () => {
    it('should validate with all fields', () => {
      const data = {
        severity: 'HIGH',
        message: 'Updated alert'
      };
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only severity', () => {
      const data = { severity: 'MEDIUM' };
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only message', () => {
      const data = { message: 'New alert text' };
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const data = {};
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate all severity values when provided', () => {
      ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].forEach(severity => {
        const data = { severity };
        const result = updateCriticalAlertSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid severity when provided', () => {
      const data = { severity: 'INVALID' };
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce min length for message when provided', () => {
      const data = { message: '' };
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for message when provided', () => {
      const data = { message: 'a'.repeat(2001) };
      const result = updateCriticalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('criticalAlertIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = criticalAlertIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = criticalAlertIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const data = {};
      const result = criticalAlertIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listCriticalAlertsQuerySchema', () => {
    it('should validate with no filters', () => {
      const data = {};
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with icu_stay_id filter', () => {
      const data = { icu_stay_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with severity filter', () => {
      const data = { severity: 'CRITICAL' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const data = { search: 'heart rate' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination parameters', () => {
      const data = { page: '2', limit: '50' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with sort parameters', () => {
      const data = { sort_by: 'severity', order: 'desc' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all parameters combined', () => {
      const data = {
        icu_stay_id: '550e8400-e29b-41d4-a716-446655440000',
        severity: 'HIGH',
        search: 'test',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid icu_stay_id UUID', () => {
      const data = { icu_stay_id: 'invalid-uuid' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid severity', () => {
      const data = { severity: 'INVALID' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim search text', () => {
      const data = { search: '  test search  ' };
      const result = listCriticalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('test search');
      }
    });
  });
});
