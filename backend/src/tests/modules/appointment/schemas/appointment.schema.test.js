/**
 * Appointment schema tests
 *
 * @module tests/modules/appointment/schemas
 * @description Tests for appointment validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createAppointmentSchema,
  updateAppointmentSchema,
  cancelAppointmentSchema,
  appointmentIdParamsSchema,
  listAppointmentsQuerySchema
} = require('@validations/appointment/appointment.schema');

describe('Appointment Schemas', () => {
  describe('createAppointmentSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'SCHEDULED',
      scheduled_start: '2026-01-20T09:00:00.000Z',
      scheduled_end: '2026-01-20T10:00:00.000Z',
      reason: 'General checkup'
    };

    it('should validate correct appointment data', () => {
      const result = createAppointmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require scheduled_start', () => {
      const data = { ...validData };
      delete data.scheduled_start;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require scheduled_end', () => {
      const data = { ...validData };
      delete data.scheduled_end;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createAppointmentSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional provider_user_id', () => {
      const data = { ...validData };
      delete data.provider_user_id;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional reason', () => {
      const data = { ...validData };
      delete data.reason;
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for patient_id', () => {
      const data = { ...validData, patient_id: 'invalid-uuid' };
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for scheduled_start', () => {
      const data = { ...validData, scheduled_start: 'not-a-date' };
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for scheduled_end', () => {
      const data = { ...validData, scheduled_end: 'not-a-date' };
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim and validate reason text', () => {
      const data = { ...validData, reason: '  Valid reason  ' };
      const result = createAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.reason).toBe('Valid reason');
    });
  });

  describe('updateAppointmentSchema', () => {
    it('should allow partial updates', () => {
      const data = { status: 'CONFIRMED' };
      const result = updateAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum if provided', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for scheduled_start if provided', () => {
      const data = { scheduled_start: 'invalid-date' };
      const result = updateAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept empty object for no updates', () => {
      const result = updateAppointmentSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate UUID format for patient_id if provided', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = updateAppointmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for optional fields', () => {
      const data = { 
        facility_id: null,
        provider_user_id: null,
        reason: null
      };
      const result = updateAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('cancelAppointmentSchema', () => {
    it('should allow optional reason', () => {
      const result = cancelAppointmentSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept reason text', () => {
      const data = { reason: 'Patient requested cancellation' };
      const result = cancelAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim reason text', () => {
      const data = { reason: '  Cancel reason  ' };
      const result = cancelAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.reason).toBe('Cancel reason');
    });

    it('should accept null reason', () => {
      const data = { reason: null };
      const result = cancelAppointmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('appointmentIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = appointmentIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = appointmentIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = appointmentIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should validate friendly id param', () => {
      const data = { id: 'APT0000123' };
      const result = appointmentIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('listAppointmentsQuerySchema', () => {
    it('should accept valid query parameters', () => {
      const data = {
        page: 1,
        limit: 20,
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440003',
        status: 'SCHEDULED',
        search: 'checkup'
      };
      const result = listAppointmentsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty query parameters', () => {
      const result = listAppointmentsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum if provided', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = listAppointmentsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for tenant_id if provided', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listAppointmentsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for patient_id if provided', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = listAppointmentsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim search parameter', () => {
      const data = { search: '  test search  ' };
      const result = listAppointmentsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.search).toBe('test search');
    });
  });
});
