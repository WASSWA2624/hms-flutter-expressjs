/**
 * Patient Guardian schema tests
 *
 * @module tests/modules/patient-guardian/schemas
 * @description Tests for patient guardian validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientGuardianSchema,
  updatePatientGuardianSchema,
  patientGuardianIdParamsSchema,
  listPatientGuardiansQuerySchema
} = require('@validations/patient-guardian/patient-guardian.schema');

describe('Patient Guardian Schemas', () => {
  describe('createPatientGuardianSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Jane Doe',
      relationship: 'Mother',
      phone: '+256700000000',
      email: 'jane.doe@example.com'
    };

    it('should validate correct data', () => {
      const result = createPatientGuardianSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional relationship', () => {
      const data = { ...validData };
      delete data.relationship;
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional phone', () => {
      const data = { ...validData };
      delete data.phone;
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional email', () => {
      const data = { ...validData };
      delete data.email;
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate email format when provided', () => {
      const data = { ...validData, email: 'invalid-email' };
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string fields', () => {
      const data = { ...validData, name: '  Jane Doe  ' };
      const result = createPatientGuardianSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Jane Doe');
      }
    });
  });

  describe('updatePatientGuardianSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updatePatientGuardianSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('patientGuardianIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientGuardianIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('listPatientGuardiansQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = { name: 'Jane', relationship: 'Mother', search: 'Doe' };
      const result = listPatientGuardiansQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
