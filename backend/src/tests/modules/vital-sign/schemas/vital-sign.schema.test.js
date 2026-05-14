/**
 * Vital Sign schema tests
 *
 * @module tests/modules/vital-sign/schemas
 * @description Tests for vital sign validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createVitalSignSchema,
  updateVitalSignSchema,
  vitalSignIdParamsSchema,
  listVitalSignsQuerySchema
} = require('@validations/vital-sign/vital-sign.schema');

describe('Vital Sign Schemas', () => {
  describe('createVitalSignSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      vital_type: 'TEMPERATURE',
      value: '98.6',
      unit: 'F',
      recorded_at: '2026-01-19T10:30:00.000Z'
    };

    it('should validate correct vital sign data', () => {
      const result = createVitalSignSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require vital_type', () => {
      const data = { ...validData };
      delete data.vital_type;
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require value', () => {
      const data = { ...validData };
      delete data.value;
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate vital_type enum values', () => {
      const data = { ...validData, vital_type: 'INVALID' };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid vital_type values', () => {
      const types = ['TEMPERATURE', 'BLOOD_PRESSURE', 'HEART_RATE', 'RESPIRATORY_RATE', 'OXYGEN_SATURATION', 'WEIGHT', 'HEIGHT', 'BMI'];
      types.forEach(vital_type => {
        const data = vital_type === 'BLOOD_PRESSURE'
          ? { ...validData, vital_type, value: '120/80' }
          : { ...validData, vital_type };
        const result = createVitalSignSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should accept blood pressure with structured components', () => {
      const data = {
        ...validData,
        vital_type: 'BLOOD_PRESSURE',
        value: undefined,
        systolic_value: '122',
        diastolic_value: '78',
        map_value: '93',
      };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject blood pressure without legacy value or structured components', () => {
      const data = {
        ...validData,
        vital_type: 'BLOOD_PRESSURE',
        value: 'invalid',
      };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional unit', () => {
      const data = { ...validData };
      delete data.unit;
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional recorded_at', () => {
      const data = { ...validData };
      delete data.recorded_at;
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from value', () => {
      const data = { ...validData, value: '  98.6  ' };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.value).toBe('98.6');
      }
    });

    it('should enforce value max length', () => {
      const data = { ...validData, value: 'a'.repeat(81) };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce unit max length', () => {
      const data = { ...validData, unit: 'a'.repeat(21) };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept nullable unit', () => {
      const data = { ...validData, unit: null };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate datetime format for recorded_at', () => {
      const data = { ...validData, recorded_at: 'invalid-date' };
      const result = createVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateVitalSignSchema', () => {
    it('should validate with all optional fields', () => {
      const data = { vital_type: 'HEART_RATE', value: '72' };
      const result = updateVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate blood pressure update with structured components', () => {
      const data = { vital_type: 'BLOOD_PRESSURE', systolic_value: '118', diastolic_value: '76' };
      const result = updateVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update data', () => {
      const result = updateVitalSignSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate optional encounter_id', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateVitalSignSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid encounter_id format', () => {
      const data = { encounter_id: 'invalid-uuid' };
      const result = updateVitalSignSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('vitalSignIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = vitalSignIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = vitalSignIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = vitalSignIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listVitalSignsQuerySchema', () => {
    it('should validate with no filters', () => {
      const result = listVitalSignsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with encounter_id filter', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listVitalSignsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with vital_type filter', () => {
      const data = { vital_type: 'TEMPERATURE' };
      const result = listVitalSignsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listVitalSignsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid vital_type', () => {
      const data = { vital_type: 'INVALID' };
      const result = listVitalSignsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
