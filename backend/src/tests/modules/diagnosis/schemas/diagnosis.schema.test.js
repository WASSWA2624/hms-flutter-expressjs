/**
 * Diagnosis schema tests
 *
 * @module tests/modules/diagnosis/schemas
 * @description Tests for diagnosis validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createDiagnosisSchema,
  updateDiagnosisSchema,
  diagnosisIdParamsSchema,
  listDiagnosesQuerySchema
} = require('@validations/diagnosis/diagnosis.schema');

describe('Diagnosis Schemas', () => {
  describe('createDiagnosisSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      diagnosis_type: 'PRIMARY',
      code: 'J00',
      description: 'Acute nasopharyngitis (common cold)'
    };

    it('should validate correct diagnosis data', () => {
      const result = createDiagnosisSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require diagnosis_type', () => {
      const data = { ...validData };
      delete data.diagnosis_type;
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require description', () => {
      const data = { ...validData };
      delete data.description;
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional code', () => {
      const data = { ...validData };
      delete data.code;
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate diagnosis_type enum values', () => {
      const types = ['PRIMARY', 'SECONDARY', 'DIFFERENTIAL'];
      types.forEach(type => {
        const data = { ...validData, diagnosis_type: type };
        const result = createDiagnosisSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid diagnosis_type', () => {
      const data = { ...validData, diagnosis_type: 'INVALID' };
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty description', () => {
      const data = { ...validData, description: '' };
      const result = createDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateDiagnosisSchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateDiagnosisSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = {
        diagnosis_type: 'SECONDARY',
        description: 'Updated diagnosis description'
      };
      const result = updateDiagnosisSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('diagnosisIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = diagnosisIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = diagnosisIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listDiagnosesQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listDiagnosesQuerySchema.safeParse({
        page: '1',
        limit: '20',
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        diagnosis_type: 'PRIMARY',
        code: 'J00'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listDiagnosesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });
});
