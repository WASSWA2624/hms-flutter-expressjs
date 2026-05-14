/**
 * Patient Identifier schema tests
 *
 * @module tests/modules/patient-identifier/schemas
 * @description Tests for patient identifier validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientIdentifierSchema,
  updatePatientIdentifierSchema,
  patientIdentifierIdParamsSchema,
  listPatientIdentifiersQuerySchema
} = require('@validations/patient-identifier/patient-identifier.schema');

describe('Patient Identifier Schemas', () => {
  describe('createPatientIdentifierSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      identifier_type: 'MRN',
      identifier_value: 'MRN123456',
      is_primary: true
    };

    it('should validate correct data', () => {
      const result = createPatientIdentifierSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require identifier_type', () => {
      const data = { ...validData };
      delete data.identifier_type;
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require identifier_value', () => {
      const data = { ...validData };
      delete data.identifier_value;
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional is_primary', () => {
      const data = { ...validData };
      delete data.is_primary;
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim string fields', () => {
      const data = { ...validData, identifier_type: '  MRN  ', identifier_value: '  MRN123456  ' };
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.identifier_type).toBe('MRN');
        expect(result.data.identifier_value).toBe('MRN123456');
      }
    });

    it('should enforce max length for identifier_type', () => {
      const data = { ...validData, identifier_type: 'a'.repeat(81) };
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for identifier_value', () => {
      const data = { ...validData, identifier_value: 'a'.repeat(121) };
      const result = createPatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePatientIdentifierSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updatePatientIdentifierSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = { identifier_value: 'NEW123' };
      const result = updatePatientIdentifierSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('patientIdentifierIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientIdentifierIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = patientIdentifierIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listPatientIdentifiersQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        patient_id: '550e8400-e29b-41d4-a716-446655440001',
        identifier_type: 'MRN',
        is_primary: 'true'
      };
      const result = listPatientIdentifiersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should transform is_primary string to boolean', () => {
      const data = { is_primary: 'true' };
      const result = listPatientIdentifiersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_primary).toBe(true);
      }
    });
  });
});
