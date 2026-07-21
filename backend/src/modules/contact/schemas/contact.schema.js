/**
 * Contact module validation schemas
 *
 * @module modules/contact/schemas
 * @description Zod validation schemas for contact endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidSchema,
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema} = require('@lib/validation/zod');

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
  'OTHER'];

const optionalScopeId = uuidOrFriendlyIdentifierSchema.optional().nullable();

// ==================== Body Schemas ====================

/**
 * Create contact body validation
 * Used for POST /contacts endpoint
 */
const createContactSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  contact_type: z.enum(CONTACT_TYPE_VALUES),
  value: z.string().trim().min(1).max(255),
  is_primary: z.boolean().optional().default(false),
  facility_id: optionalScopeId,
  patient_id: optionalScopeId,
  user_profile_id: optionalScopeId,
  staff_profile_id: optionalScopeId,
  supplier_id: optionalScopeId});

/**
 * Update contact body validation
 * Used for PUT /contacts/:id endpoint
 * All fields optional for partial updates
 */
const updateContactSchema = z.object({
  contact_type: z.enum(CONTACT_TYPE_VALUES).optional(),
  value: z.string().trim().min(1).max(255).optional(),
  is_primary: z.boolean().optional(),
  facility_id: optionalScopeId,
  patient_id: optionalScopeId,
  user_profile_id: optionalScopeId,
  staff_profile_id: optionalScopeId,
  supplier_id: optionalScopeId});

// ==================== URL Params ====================

/**
 * Contact ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const contactIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

// ==================== Query Params ====================

/**
 * List contacts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with contact-specific filters
 */
const listContactsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  contact_type: z.enum(CONTACT_TYPE_VALUES).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  supplier_id: uuidOrFriendlyIdentifierSchema.optional(),
  is_primary: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()});

module.exports = {
  createContactSchema,
  updateContactSchema,
  contactIdParamsSchema,
  listContactsQuerySchema};
