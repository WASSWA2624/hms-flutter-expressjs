/**
 * Appointment reminder module validation schemas
 *
 * @module modules/appointment-reminder/schemas
 * @description Zod validation schemas for appointment reminder endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create appointment reminder body validation
 * Used for POST /appointment-reminders endpoint
 */
const createAppointmentReminderSchema = z.object({
  appointment_id: uuidOrFriendlyIdentifierSchema,
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']),
  scheduled_at: z.string().datetime(),
  sent_at: z.string().datetime().optional().nullable()
});

/**
 * Update appointment reminder body validation
 * Used for PUT /appointment-reminders/:id endpoint
 * All fields optional for partial updates
 */
const updateAppointmentReminderSchema = z.object({
  appointment_id: uuidOrFriendlyIdentifierSchema.optional(),
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']).optional(),
  scheduled_at: z.string().datetime().optional(),
  sent_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Appointment reminder ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const appointmentReminderIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const markAppointmentReminderSentSchema = z.object({
  sent_at: z.string().datetime().optional()
});

// ==================== Query Params ====================

/**
 * List appointment reminders query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with appointment-reminder-specific filters
 */
const listAppointmentRemindersQuerySchema = listQuerySchema.extend({
  appointment_id: uuidOrFriendlyIdentifierSchema.optional(),
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']).optional(),
  is_sent: z.enum(['true', 'false']).optional().transform((value) => (value === undefined ? undefined : value === 'true')),
  due_state: z.enum(['DUE', 'OVERDUE']).optional()
});

module.exports = {
  createAppointmentReminderSchema,
  updateAppointmentReminderSchema,
  markAppointmentReminderSentSchema,
  appointmentReminderIdParamsSchema,
  listAppointmentRemindersQuerySchema
};
