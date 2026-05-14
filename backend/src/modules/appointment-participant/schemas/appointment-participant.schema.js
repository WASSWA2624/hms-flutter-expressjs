/**
 * Appointment participant module validation schemas
 *
 * @module modules/appointment-participant/schemas
 * @description Zod validation schemas for appointment participant endpoints.
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
 * Create appointment participant body validation
 * Used for POST /appointment-participants endpoint
 */
const createAppointmentParticipantSchema = z.object({
  appointment_id: uuidOrFriendlyIdentifierSchema,
  participant_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  participant_patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  role: z.string().trim().max(80).optional().nullable()
});

/**
 * Update appointment participant body validation
 * Used for PUT /appointment-participants/:id endpoint
 * All fields optional for partial updates
 */
const updateAppointmentParticipantSchema = z.object({
  appointment_id: uuidOrFriendlyIdentifierSchema.optional(),
  participant_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  participant_patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  role: z.string().trim().max(80).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Appointment participant ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const appointmentParticipantIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List appointment participants query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with appointment-participant-specific filters
 */
const listAppointmentParticipantsQuerySchema = listQuerySchema.extend({
  appointment_id: uuidOrFriendlyIdentifierSchema.optional(),
  participant_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  participant_patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  role: z.string().trim().optional()
});

module.exports = {
  createAppointmentParticipantSchema,
  updateAppointmentParticipantSchema,
  appointmentParticipantIdParamsSchema,
  listAppointmentParticipantsQuerySchema
};
