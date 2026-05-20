/**
 * Patient schema tests
 *
 * @module tests/modules/patient/schemas
 * @description Tests for patient validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientSchema,
  updatePatientSchema,
  patientIdParamsSchema,
  listPatientsQuerySchema
} = require('@validations/patient/patient.schema');

describe('Patient Schemas', () => {
  describe('createPatientSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      first_name: 'John',
      last_name: 'Doe',
      date_of_birth: '1990-01-01T00:00:00.000Z',
      gender: 'MALE',
      is_active: true
    };

    it('should validate correct patient data', () => {
      const result = createPatientSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow tenant_id to be injected from request scope', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should require first_name', () => {
      const data = { ...validData };
      delete data.first_name;
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow last_name to be omitted', () => {
      const data = { ...validData };
      delete data.last_name;
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should normalize blank last_name to null', () => {
      const data = { ...validData, last_name: '   ' };
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.last_name).toBeNull();
      }
    });

    it('should accept optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional date_of_birth', () => {
      const data = { ...validData };
      delete data.date_of_birth;
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional gender', () => {
      const data = { ...validData };
      delete data.gender;
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate gender enum', () => {
      const data = { ...validData, gender: 'INVALID' };
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string fields', () => {
      const data = { ...validData, first_name: '  John  ', last_name: '  Doe  ' };
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.first_name).toBe('John');
        expect(result.data.last_name).toBe('Doe');
      }
    });

    it('should enforce max length for first_name', () => {
      const data = { ...validData, first_name: 'a'.repeat(121) };
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for last_name', () => {
      const data = { ...validData, last_name: 'a'.repeat(121) };
      const result = createPatientSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePatientSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updatePatientSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = { first_name: 'Jane' };
      const result = updatePatientSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate gender enum when provided', () => {
      const data = { gender: 'INVALID' };
      const result = updatePatientSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('patientIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate human-friendly id param and normalize to uppercase', () => {
      const data = { id: 'pat0000001' };
      const result = patientIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.id).toBe('PAT0000001');
      }
    });

    it('should reject invalid patient identifier', () => {
      const data = { id: 'invalid-uuid' };
      const result = patientIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = patientIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listPatientsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filter params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: 'PAT-00021',
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: '1990-01-02',
        date_of_birth_from: '1980-01-01',
        date_of_birth_to: '2000-12-31',
        gender: 'MALE',
        contact: '+256700000001',
        appointment_status: 'CONFIRMED',
        created_at: '2026-02-01',
        created_from: '2026-01-01',
        created_to: '2026-02-28',
        appointment_from: '2026-02-01',
        appointment_to: '2026-03-01',
        is_active: 'true',
        search: 'test'
      };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should transform is_active string to boolean', () => {
      const data = { is_active: 'true' };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_active).toBe(true);
      }
    });

    it('should normalize search by trimming and collapsing whitespace', () => {
      const data = { search: '   john    guardian   phone   ' };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('john guardian phone');
      }
    });

    it('should coerce blank search to undefined', () => {
      const data = { search: '     ' };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBeUndefined();
      }
    });

    it('should reject search longer than 120 characters', () => {
      const data = { search: 'a'.repeat(121) };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date filter strings', () => {
      const data = { created_from: 'not-a-date' };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate gender enum in query', () => {
      const data = { gender: 'INVALID' };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate appointment status enum in query', () => {
      const data = { appointment_status: 'INVALID' };
      const result = listPatientsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
