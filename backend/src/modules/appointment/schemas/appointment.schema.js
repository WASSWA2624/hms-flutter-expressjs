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

const appointmentSubjectTypeSchema = z.enum(['PATIENT', 'VISITOR']);

const appointmentStatusSchema = z.enum([
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
]);

const visitorFieldsSchema = {
  visitor_name: z.string().trim().min(1).max(160).optional().nullable(),
  visitor_phone: z.string().trim().max(40).optional().nullable(),
  visitor_email: z.string().trim().email().max(160).optional().nullable().or(z.literal('')),
  visitor_organization: z.string().trim().max(160).optional().nullable(),
};

/**
 * Create appointment body validation
 * Used for POST /appointments endpoint
 */
const createAppointmentSchema = z
  .object({
    tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
    facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    provider_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    subject_type: appointmentSubjectTypeSchema.optional().default('PATIENT'),
    status: appointmentStatusSchema,
    scheduled_start: z.string().datetime(),
    scheduled_end: z.string().datetime(),
    reason: z.string().trim().max(65535).optional().nullable(),
    ...visitorFieldsSchema,
  })
  .superRefine((value, ctx) => {
    const subjectType = String(value.subject_type || 'PATIENT').toUpperCase();
    if (subjectType === 'VISITOR') {
      if (!value.visitor_name || !String(value.visitor_name).trim()) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['visitor_name'],
          message: 'Visitor name is required for visitor appointments',
        });
      }
      if (!value.provider_user_id) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['provider_user_id'],
          message: 'Staff host is required for visitor appointments',
        });
      }
      if (value.patient_id) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['patient_id'],
          message: 'Visitor appointments must not include a patient',
        });
      }
      return;
    }
    if (!value.patient_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['patient_id'],
        message: 'Patient is required for clinical appointments',
      });
    }
  });

/**
 * Update appointment body validation
 * Used for PUT /appointments/:id endpoint
 * All fields optional for partial updates
 */
const updateAppointmentSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  provider_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  subject_type: appointmentSubjectTypeSchema.optional(),
  status: appointmentStatusSchema.optional(),
  scheduled_start: z.string().datetime().optional(),
  scheduled_end: z.string().datetime().optional(),
  reason: z.string().trim().max(65535).optional().nullable(),
  ...visitorFieldsSchema,
});

/**
 * Cancel appointment body validation
 * Used for POST /appointments/:id/cancel endpoint
 */
const cancelAppointmentSchema = z.object({
  reason: z.string().trim().max(65535).optional().nullable()
});

/**
 * Appointment ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and POST /:id/cancel endpoints
 */
const appointmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

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
  subject_type: appointmentSubjectTypeSchema.optional(),
  status: appointmentStatusSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAppointmentSchema,
  updateAppointmentSchema,
  cancelAppointmentSchema,
  appointmentIdParamsSchema,
  listAppointmentsQuerySchema
};
