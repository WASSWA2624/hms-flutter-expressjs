/**
 * Patient Contact module validation schemas
 *
 * @module modules/patient-contact/schemas
 * @description Zod validation schemas for patient-contact endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const CONTACT_TYPE_VALUES = [
  'PHONE',
  'EMAIL',
  'WHATSAPP',
  'TELEGRAM',
  'TIKTOK',
  'INSTAGRAM',
  'FACEBOOK',
  'LINKEDIN',
  'X',
  'YOUTUBE',
  'PINTEREST',
  'REDDIT',
  'DISCORD',
  'FAX',
  'OTHER',
];
const PHONE_LIKE_CONTACT_TYPES = new Set(['PHONE', 'WHATSAPP', 'FAX']);
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^\+?[0-9 ()-]{6,40}$/;

const validateContactValue = (payload, ctx) => {
  const contactType = String(payload?.contact_type || '').trim().toUpperCase();
  const value = String(payload?.value || '').trim();
  if (!contactType || !value) return;

  if (PHONE_LIKE_CONTACT_TYPES.has(contactType) && !PHONE_PATTERN.test(value)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['value'],
      message: 'errors.patient_contact.invalid_phone',
    });
    return;
  }

  if (contactType === 'EMAIL' && !EMAIL_PATTERN.test(value)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['value'],
      message: 'errors.patient_contact.invalid_email',
    });
  }
};

// ==================== Body Schemas ====================

/**
 * Create patient contact body validation
 * Used for POST /patient-contacts endpoint
 */
const createPatientContactSchema = z.object({
  tenant_id: uuidSchema,
  patient_id: uuidSchema,
  contact_type: z.enum(CONTACT_TYPE_VALUES),
  value: z.string().trim().min(1).max(255),
  is_primary: z.boolean().optional()
}).superRefine(validateContactValue);

/**
 * Update patient contact body validation
 * Used for PUT /patient-contacts/:id endpoint
 * All fields optional for partial updates
 */
const updatePatientContactSchema = z.object({
  contact_type: z.enum(CONTACT_TYPE_VALUES).optional(),
  value: z.string().trim().min(1).max(255).optional(),
  is_primary: z.boolean().optional()
}).superRefine(validateContactValue);

// ==================== URL Params ====================

/**
 * Patient Contact ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const patientContactIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List patient contacts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with patient-contact-specific filters
 */
const listPatientContactsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  contact_type: z.enum(CONTACT_TYPE_VALUES).optional(),
  value: z.string().trim().optional(),
  is_primary: z.string().transform(val => val === 'true').optional()
});

module.exports = {
  createPatientContactSchema,
  updatePatientContactSchema,
  patientContactIdParamsSchema,
  listPatientContactsQuerySchema
};
