/**
 * Appointment module validation schemas
 *
 * @module modules/appointment/schemas
 * @description Zod validation schemas for appointment endpoints.
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
 * Create appointment body validation
 * Used for POST /appointments endpoint
 */
const createAppointmentSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema,
  provider_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW']),
  scheduled_start: z.string().datetime(),
  scheduled_end: z.string().datetime(),
  reason: z.string().trim().max(65535).optional().nullable()
});

/**
 * Update appointment body validation
 * Used for PUT /appointments/:id endpoint
 * All fields optional for partial updates
 */
const updateAppointmentSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  provider_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW']).optional(),
  scheduled_start: z.string().datetime().optional(),
  scheduled_end: z.string().datetime().optional(),
  reason: z.string().trim().max(65535).optional().nullable()
});

/**
 * Cancel appointment body validation
 * Used for POST /appointments/:id/cancel endpoint
 */
const cancelAppointmentSchema = z.object({
  reason: z.string().trim().max(65535).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Appointment ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and POST /:id/cancel endpoints
 */
const appointmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List appointments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with appointment-specific filters
 */
const listAppointmentsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  provider_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAppointmentSchema,
  updateAppointmentSchema,
  cancelAppointmentSchema,
  appointmentIdParamsSchema,
  listAppointmentsQuerySchema
};
