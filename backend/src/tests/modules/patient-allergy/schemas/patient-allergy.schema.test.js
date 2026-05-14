/**
 * Patient Allergy schema tests
 *
 * @module tests/modules/patient-allergy/schemas
 * @description Tests for patient allergy validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientAllergySchema,
  updatePatientAllergySchema,
  patientAllergyIdParamsSchema,
  listPatientAllergiesQuerySchema
} = require('@validations/patient-allergy/patient-allergy.schema');

describe('Patient Allergy Schemas', () => {
  describe('createPatientAllergySchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      allergen: 'Penicillin',
      severity: 'MODERATE',
      reaction: 'Rash',
      notes: 'Patient developed rash after taking penicillin'
    };

    it('should validate correct patient allergy data', () => {
      const result = createPatientAllergySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require allergen', () => {
      const data = { ...validData };
      delete data.allergen;
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require severity', () => {
      const data = { ...validData };
      delete data.severity;
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate severity enum values', () => {
      const data = { ...validData, severity: 'INVALID' };
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid severity values', () => {
      const severities = ['MILD', 'MODERATE', 'SEVERE'];
      severities.forEach(severity => {
        const data = { ...validData, severity };
        const result = createPatientAllergySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional reaction', () => {
      const data = { ...validData };
      delete data.reaction;
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional notes', () => {
      const data = { ...validData };
      delete data.notes;
      const result = createPatientAllergySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updatePatientAllergySchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        allergen: 'Updated Allergen',
        severity: 'SEVERE',
        reaction: 'Updated Reaction',
        notes: 'Updated notes'
      };
      const result = updatePatientAllergySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { allergen: 'Updated Allergen' };
      const result = updatePatientAllergySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate severity enum in updates', () => {
      const data = { severity: 'INVALID' };
      const result = updatePatientAllergySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('patientAllergyIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientAllergyIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = patientAllergyIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const params = {};
      const result = patientAllergyIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listPatientAllergiesQuerySchema', () => {
    it('should validate empty query', () => {
      const query = {};
      const result = listPatientAllergiesQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const query = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        patient_id: '550e8400-e29b-41d4-a716-446655440001',
        allergen: 'Penicillin',
        severity: 'MODERATE',
        search: 'test'
      };
      const result = listPatientAllergiesQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate severity filter enum', () => {
      const query = { severity: 'INVALID' };
      const result = listPatientAllergiesQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });
  });
});
