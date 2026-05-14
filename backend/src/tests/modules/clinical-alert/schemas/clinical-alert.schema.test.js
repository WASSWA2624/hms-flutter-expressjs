/**
 * Clinical Alert schema tests
 *
 * @module tests/modules/clinical-alert/schemas
 * @description Tests for clinical alert validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createClinicalAlertSchema,
  updateClinicalAlertSchema,
  clinicalAlertIdParamsSchema,
  listClinicalAlertsQuerySchema
} = require('@validations/clinical-alert/clinical-alert.schema');

describe('Clinical Alert Schemas', () => {
  describe('createClinicalAlertSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      severity: 'HIGH',
      message: 'Patient showing signs of distress'
    };

    it('should validate correct clinical alert data', () => {
      const result = createClinicalAlertSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require severity', () => {
      const data = { ...validData };
      delete data.severity;
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require message', () => {
      const data = { ...validData };
      delete data.message;
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate severity enum values', () => {
      const data = { ...validData, severity: 'INVALID' };
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid severity values', () => {
      const severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
      severities.forEach(severity => {
        const data = { ...validData, severity };
        const result = createClinicalAlertSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid UUID format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from message', () => {
      const data = { ...validData, message: '  Alert message  ' };
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.message).toBe('Alert message');
      }
    });

    it('should reject empty message', () => {
      const data = { ...validData, message: '' };
      const result = createClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateClinicalAlertSchema', () => {
    it('should validate with all optional fields', () => {
      const data = { severity: 'CRITICAL' };
      const result = updateClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update data', () => {
      const result = updateClinicalAlertSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate optional encounter_id', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid severity', () => {
      const data = { severity: 'INVALID' };
      const result = updateClinicalAlertSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('clinicalAlertIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = clinicalAlertIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = clinicalAlertIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listClinicalAlertsQuerySchema', () => {
    it('should validate with no filters', () => {
      const result = listClinicalAlertsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with encounter_id filter', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listClinicalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with severity filter', () => {
      const data = { severity: 'CRITICAL' };
      const result = listClinicalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listClinicalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid severity', () => {
      const data = { severity: 'INVALID' };
      const result = listClinicalAlertsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
