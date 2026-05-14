/**
 * Patient Medical History schema tests
 *
 * @module tests/modules/patient-medical-history/schemas
 * @description Tests for patient medical history validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientMedicalHistorySchema,
  updatePatientMedicalHistorySchema,
  patientMedicalHistoryIdParamsSchema,
  listPatientMedicalHistoriesQuerySchema
} = require('@validations/patient-medical-history/patient-medical-history.schema');

describe('Patient Medical History Schemas', () => {
  describe('createPatientMedicalHistorySchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      condition: 'Hypertension',
      diagnosis_date: '2024-01-15T00:00:00.000Z',
      notes: 'Patient diagnosed with high blood pressure'
    };

    it('should validate correct patient medical history data', () => {
      const result = createPatientMedicalHistorySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createPatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require condition', () => {
      const data = { ...validData };
      delete data.condition;
      const result = createPatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional diagnosis_date', () => {
      const data = { ...validData };
      delete data.diagnosis_date;
      const result = createPatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional notes', () => {
      const data = { ...validData };
      delete data.notes;
      const result = createPatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate ISO date format', () => {
      const data = { ...validData, diagnosis_date: 'invalid-date' };
      const result = createPatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePatientMedicalHistorySchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        condition: 'Updated Condition',
        diagnosis_date: '2024-02-15T00:00:00.000Z',
        notes: 'Updated notes'
      };
      const result = updatePatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { condition: 'Updated Condition' };
      const result = updatePatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate ISO date format in updates', () => {
      const data = { diagnosis_date: 'invalid-date' };
      const result = updatePatientMedicalHistorySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('patientMedicalHistoryIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientMedicalHistoryIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = patientMedicalHistoryIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const params = {};
      const result = patientMedicalHistoryIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listPatientMedicalHistoriesQuerySchema', () => {
    it('should validate empty query', () => {
      const query = {};
      const result = listPatientMedicalHistoriesQuerySchema.safeParse(query);
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
        condition: 'Hypertension',
        search: 'test'
      };
      const result = listPatientMedicalHistoriesQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });
  });
});
