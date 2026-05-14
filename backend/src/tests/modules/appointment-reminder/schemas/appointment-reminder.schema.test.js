/**
 * Appointment reminder schema tests
 *
 * @module tests/modules/appointment-reminder/schemas
 * @description Tests for appointment reminder validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createAppointmentReminderSchema,
  updateAppointmentReminderSchema,
  markAppointmentReminderSentSchema,
  appointmentReminderIdParamsSchema,
  listAppointmentRemindersQuerySchema
} = require('@validations/appointment-reminder/appointment-reminder.schema');

describe('Appointment Reminder Schemas', () => {
  describe('createAppointmentReminderSchema', () => {
    const validData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440000',
      channel: 'EMAIL',
      scheduled_at: '2026-01-20T08:00:00.000Z',
      sent_at: '2026-01-20T08:05:00.000Z'
    };

    it('should validate correct appointment reminder data', () => {
      const result = createAppointmentReminderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require appointment_id', () => {
      const data = { ...validData };
      delete data.appointment_id;
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require channel', () => {
      const data = { ...validData };
      delete data.channel;
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require scheduled_at', () => {
      const data = { ...validData };
      delete data.scheduled_at;
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional sent_at', () => {
      const data = { ...validData };
      delete data.sent_at;
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate channel enum values', () => {
      const data = { ...validData, channel: 'INVALID' };
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid channel values', () => {
      const channels = ['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP'];
      channels.forEach(channel => {
        const data = { ...validData, channel };
        const result = createAppointmentReminderSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid UUID format for appointment_id', () => {
      const data = { ...validData, appointment_id: 'invalid-uuid' };
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for scheduled_at', () => {
      const data = { ...validData, scheduled_at: 'not-a-date' };
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for sent_at', () => {
      const data = { ...validData, sent_at: 'not-a-date' };
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for sent_at', () => {
      const data = { ...validData, sent_at: null };
      const result = createAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateAppointmentReminderSchema', () => {
    it('should allow partial updates', () => {
      const data = { channel: 'SMS' };
      const result = updateAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate channel enum if provided', () => {
      const data = { channel: 'INVALID_CHANNEL' };
      const result = updateAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for scheduled_at if provided', () => {
      const data = { scheduled_at: 'invalid-date' };
      const result = updateAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for sent_at if provided', () => {
      const data = { sent_at: 'invalid-date' };
      const result = updateAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept empty object for no updates', () => {
      const result = updateAppointmentReminderSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept null for sent_at', () => {
      const data = { sent_at: null };
      const result = updateAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid datetime for scheduled_at', () => {
      const data = { scheduled_at: '2026-01-20T09:00:00.000Z' };
      const result = updateAppointmentReminderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('appointmentReminderIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = appointmentReminderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = appointmentReminderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = appointmentReminderIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should validate friendly id', () => {
      const result = appointmentReminderIdParamsSchema.safeParse({ id: 'APR0000123' });
      expect(result.success).toBe(true);
    });
  });

  describe('listAppointmentRemindersQuerySchema', () => {
    it('should accept valid query parameters', () => {
      const data = {
        page: 1,
        limit: 20,
        appointment_id: '550e8400-e29b-41d4-a716-446655440000',
        channel: 'EMAIL',
        is_sent: 'true',
        due_state: 'DUE',
      };
      const result = listAppointmentRemindersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty query parameters', () => {
      const result = listAppointmentRemindersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate channel enum if provided', () => {
      const data = { channel: 'INVALID_CHANNEL' };
      const result = listAppointmentRemindersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format for appointment_id if provided', () => {
      const data = { appointment_id: 'invalid-uuid' };
      const result = listAppointmentRemindersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid channel values', () => {
      const channels = ['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP'];
      channels.forEach(channel => {
        const data = { channel };
        const result = listAppointmentRemindersQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should accept valid due state values', () => {
      ['DUE', 'OVERDUE'].forEach((due_state) => {
        const result = listAppointmentRemindersQuerySchema.safeParse({ due_state });
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid due state value', () => {
      const result = listAppointmentRemindersQuerySchema.safeParse({ due_state: 'SENT' });
      expect(result.success).toBe(false);
    });

    it('should parse is_sent boolean values', () => {
      const positive = listAppointmentRemindersQuerySchema.safeParse({ is_sent: 'true' });
      const negative = listAppointmentRemindersQuerySchema.safeParse({ is_sent: 'false' });
      expect(positive.success).toBe(true);
      expect(negative.success).toBe(true);
      expect(positive.success && positive.data.is_sent).toBe(true);
      expect(negative.success && negative.data.is_sent).toBe(false);
    });
  });

  describe('markAppointmentReminderSentSchema', () => {
    it('should accept empty body', () => {
      const result = markAppointmentReminderSentSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept valid sent_at datetime', () => {
      const result = markAppointmentReminderSentSchema.safeParse({ sent_at: '2026-01-20T08:05:00.000Z' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid sent_at datetime', () => {
      const result = markAppointmentReminderSentSchema.safeParse({ sent_at: 'invalid-date' });
      expect(result.success).toBe(false);
    });
  });
});
