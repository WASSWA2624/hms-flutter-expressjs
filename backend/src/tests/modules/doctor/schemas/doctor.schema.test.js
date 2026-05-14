const {
  createDoctorSchema,
  updateDoctorSchema,
  doctorIdParamsSchema,
  listDoctorsQuerySchema,
} = require('@validations/doctor/doctor.schema');

describe('doctor.schema', () => {
  describe('createDoctorSchema', () => {
    it('validates specialist onboarding payload with fee override', () => {
      const result = createDoctorSchema.safeParse({
        tenant_id: 'ten0000001',
        facility_id: 'fac0000001',
        email: 'specialist@hms.test',
        password: 'StrongP@ssword1',
        status: 'ACTIVE',
        position_title: 'Neurologist',
        practitioner_type: 'SPECIALIST',
        position_id: 'pos0000001',
        consultation_fee: '120.00',
        consultation_currency: 'usd',
        is_fee_overridden: true,
        role_ids: ['rol0000001'],
      });

      expect(result.success).toBe(true);
      expect(result.data.tenant_id).toBe('TEN0000001');
      expect(result.data.facility_id).toBe('FAC0000001');
      expect(result.data.position_id).toBe('POS0000001');
      expect(result.data.role_ids).toEqual(['ROL0000001']);
    });

    it('rejects missing or blank position_title', () => {
      const result = createDoctorSchema.safeParse({
        tenant_id: 'TEN0000001',
        email: 'doctor@hms.test',
        password: 'StrongP@ssword1',
        practitioner_type: 'MO',
        position_title: '   ',
      });

      expect(result.success).toBe(false);
    });

    it('rejects UUID-like identifiers in public payload fields', () => {
      const result = createDoctorSchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        email: 'doctor@hms.test',
        password: 'StrongP@ssword1',
        practitioner_type: 'MO',
        position_title: 'Medical Officer',
      });

      expect(result.success).toBe(false);
    });
  });

  describe('updateDoctorSchema', () => {
    it('accepts partial update payload', () => {
      const result = updateDoctorSchema.safeParse({
        position_title: 'Consultant Physician',
        practitioner_type: 'SPECIALIST',
        consultation_fee: '200.00',
        consultation_currency: 'EUR',
        is_fee_overridden: true,
      });

      expect(result.success).toBe(true);
    });
  });

  describe('doctorIdParamsSchema', () => {
    it('accepts friendly doctor id and normalizes to uppercase', () => {
      const result = doctorIdParamsSchema.safeParse({ id: 'doc0000012' });
      expect(result.success).toBe(true);
      expect(result.data.id).toBe('DOC0000012');
    });
  });

  describe('listDoctorsQuerySchema', () => {
    it('accepts friendly filters and search', () => {
      const result = listDoctorsQuerySchema.safeParse({
        tenant_id: 'ten0000001',
        facility_id: 'fac0000001',
        practitioner_type: 'MO',
        search: 'neurologist',
      });

      expect(result.success).toBe(true);
      expect(result.data.tenant_id).toBe('TEN0000001');
      expect(result.data.facility_id).toBe('FAC0000001');
    });
  });
});
