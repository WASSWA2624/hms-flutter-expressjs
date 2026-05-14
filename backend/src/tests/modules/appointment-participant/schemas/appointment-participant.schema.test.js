/**
 * Appointment participant schema tests
 *
 * @module tests/modules/appointment-participant/schemas
 * @description Tests for appointment participant validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createAppointmentParticipantSchema,
  updateAppointmentParticipantSchema,
  appointmentParticipantIdParamsSchema,
  listAppointmentParticipantsQuerySchema
} = require('@validations/appointment-participant/appointment-participant.schema');

describe('Appointment Participant Schemas', () => {
  describe('createAppointmentParticipantSchema', () => {
    const validData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440000',
      participant_user_id: '550e8400-e29b-41d4-a716-446655440001',
      participant_patient_id: '550e8400-e29b-41d4-a716-446655440002',
      role: 'Primary Provider'
    };

    it('should validate correct appointment participant data', () => {
      const result = createAppointmentParticipantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require appointment_id', () => {
      const data = { ...validData };
      delete data.appointment_id;
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional participant_user_id', () => {
      const data = { ...validData };
      delete data.participant_user_id;
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional participant_patient_id', () => {
      const data = { ...validData };
      delete data.participant_patient_id;
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional role', () => {
      const data = { ...validData };
      delete data.role;
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for appointment_id', () => {
      const data = { ...validData, appointment_id: 'invalid-uuid' };
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for participant_user_id', () => {
      const data = { ...validData, participant_user_id: 'invalid-uuid' };
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for participant_patient_id', () => {
      const data = { ...validData, participant_patient_id: 'invalid-uuid' };
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim and validate role text', () => {
      const data = { ...validData, role: '  Valid role  ' };
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject role longer than 80 characters', () => {
      const data = { ...validData, role: 'a'.repeat(81) };
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for optional fields', () => {
      const data = {
        appointment_id: '550e8400-e29b-41d4-a716-446655440000',
        participant_user_id: null,
        participant_patient_id: null,
        role: null
      };
      const result = createAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateAppointmentParticipantSchema', () => {
    it('should allow partial updates', () => {
      const data = { role: 'Updated Role' };
      const result = updateAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate UUID format for participant_user_id if provided', () => {
      const data = { participant_user_id: 'invalid-uuid' };
      const result = updateAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for participant_patient_id if provided', () => {
      const data = { participant_patient_id: 'invalid-uuid' };
      const result = updateAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept empty object for no updates', () => {
      const result = updateAppointmentParticipantSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept null for optional fields', () => {
      const data = { 
        participant_user_id: null,
        participant_patient_id: null,
        role: null
      };
      const result = updateAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject role longer than 80 characters', () => {
      const data = { role: 'a'.repeat(81) };
      const result = updateAppointmentParticipantSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('appointmentParticipantIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = appointmentParticipantIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = appointmentParticipantIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = appointmentParticipantIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should validate friendly id', () => {
      const result = appointmentParticipantIdParamsSchema.safeParse({ id: 'APP0000123' });
      expect(result.success).toBe(true);
    });
  });

  describe('listAppointmentParticipantsQuerySchema', () => {
    it('should accept valid query parameters', () => {
      const data = {
        page: 1,
        limit: 20,
        appointment_id: '550e8400-e29b-41d4-a716-446655440000',
        participant_user_id: '550e8400-e29b-41d4-a716-446655440001',
        participant_patient_id: '550e8400-e29b-41d4-a716-446655440002',
        role: 'Provider'
      };
      const result = listAppointmentParticipantsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty query parameters', () => {
      const result = listAppointmentParticipantsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate UUID format for appointment_id if provided', () => {
      const data = { appointment_id: 'invalid-uuid' };
      const result = listAppointmentParticipantsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for participant_user_id if provided', () => {
      const data = { participant_user_id: 'invalid-uuid' };
      const result = listAppointmentParticipantsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for participant_patient_id if provided', () => {
      const data = { participant_patient_id: 'invalid-uuid' };
      const result = listAppointmentParticipantsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim role parameter', () => {
      const data = { role: '  test role  ' };
      const result = listAppointmentParticipantsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
