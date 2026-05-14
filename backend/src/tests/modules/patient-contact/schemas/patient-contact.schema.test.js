/**
 * Patient Contact schema tests
 *
 * @module tests/modules/patient-contact/schemas
 * @description Tests for patient contact validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientContactSchema,
  updatePatientContactSchema,
  patientContactIdParamsSchema,
  listPatientContactsQuerySchema
} = require('@validations/patient-contact/patient-contact.schema');

describe('Patient Contact Schemas', () => {
  describe('createPatientContactSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      contact_type: 'PHONE',
      value: '+256700000000',
      is_primary: true
    };

    it('should validate correct data', () => {
      const result = createPatientContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientContactSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require contact_type', () => {
      const data = { ...validData };
      delete data.contact_type;
      const result = createPatientContactSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate contact_type enum', () => {
      const data = { ...validData, contact_type: 'INVALID' };
      const result = createPatientContactSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid contact types', () => {
      const types = ['PHONE', 'EMAIL', 'FAX', 'OTHER'];
      types.forEach(type => {
        const data = { ...validData, contact_type: type };
        const result = createPatientContactSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });
  });

  describe('updatePatientContactSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updatePatientContactSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('patientContactIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientContactIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('listPatientContactsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = { contact_type: 'PHONE', is_primary: 'true' };
      const result = listPatientContactsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
