/**
 * Tenant module validation schemas
 *
 * @module modules/tenant/schemas
 * @description Zod validation schemas for tenant endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema 
} = require('@lib/validation/zod');

const optionalBooleanSchema = z.preprocess((value) => {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
  }
  return value;
}, z.boolean().optional());

const optionalEmailSchema = z.preprocess((value) => {
  if (value == null) return value;
  const normalized = String(value).trim();
  return normalized === '' ? null : normalized.toLowerCase();
}, z.string().email().max(255).optional().nullable());

const requiredEmailSchema = z.preprocess((value) => {
  if (value == null) return value;
  return String(value).trim().toLowerCase();
}, z.string().trim().min(1).email().max(255));

const optionalPhoneSchema = z.preprocess((value) => {
  if (value == null) return value;
  const normalized = String(value).trim();
  return normalized === '' ? null : normalized;
}, z.string().min(3).max(40).optional().nullable());

const requiredPhoneSchema = z.preprocess((value) => {
  if (value == null) return value;
  return String(value).trim();
}, z.string().trim().min(3).max(40));

const optionalCurrencySchema = z.preprocess((value) => {
  if (value == null) return value;
  const normalized = String(value).trim().toUpperCase();
  return normalized === '' ? null : normalized;
}, z.string().length(3).regex(/^[A-Z]{3}$/).optional().nullable());

const optionalFeeSchema = z.preprocess((value) => {
  if (value == null || value === '') return null;
  if (typeof value === 'number') return value;
  const normalized = String(value).replace(/,/g, '').trim();
  if (!normalized) return null;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : value;
}, z.number().finite().nonnegative().optional().nullable());

const slugSchema = z
  .string()
  .trim()
  .min(1)
  .max(191)
  .regex(
    /^[a-z0-9]+(?:-[a-z0-9]+)*$/,
    'Slug must be lowercase letters, numbers, and hyphens'
  );

const optionalContactSchema = z
  .object({
    name: z.string().trim().max(255).optional().nullable(),
    email: optionalEmailSchema,
    phone: optionalPhoneSchema
  })
  .partial()
  .optional()
  .nullable();

const requiredContactSchema = z.object({
  name: z.string().trim().min(1).max(255),
  email: requiredEmailSchema,
  phone: requiredPhoneSchema
});

const billingSchema = z
  .object({
    standard_consultation_fee: optionalFeeSchema
  })
  .partial()
  .optional()
  .nullable();

const createExtensionJsonSchema = z
  .object({
    currency: optionalCurrencySchema,
    billing: billingSchema,
    contact: requiredContactSchema
  })
  .passthrough();

const updateExtensionJsonSchema = z
  .object({
    currency: optionalCurrencySchema,
    billing: billingSchema,
    contact: optionalContactSchema
  })
  .passthrough()
  .optional()
  .nullable();

// ==================== Body Schemas ====================

/**
 * Create tenant body validation
 * Used for POST /tenants endpoint
 */
const createTenantSchema = z.object({
  name: z.string().trim().min(1).max(255),
  slug: slugSchema.optional(),
  is_active: z.boolean().optional(),
  confirm_similar: optionalBooleanSchema,
  extension_json: createExtensionJsonSchema
});

/**
 * Update tenant body validation
 * Used for PUT /tenants/:id endpoint
 * All fields optional for partial updates
 */
const updateTenantSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  slug: slugSchema.optional().nullable(),
  is_active: z.boolean().optional(),
  confirm_similar: optionalBooleanSchema,
  extension_json: updateExtensionJsonSchema
});

// ==================== URL Params ====================

/**
 * Tenant ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const tenantIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List tenants query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with tenant-specific filters
 */
const listTenantsQuerySchema = listQuerySchema.extend({
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional(),
  include_deleted: z.enum(['true', 'false']).optional()});

/**
 * Permanent delete query validation
 * Used for DELETE /tenants/:id/permanent
 */
const permanentDeleteTenantQuerySchema = z.object({
  force: optionalBooleanSchema});

module.exports = {
  createTenantSchema,
  updateTenantSchema,
  tenantIdParamsSchema,
  listTenantsQuerySchema,
  permanentDeleteTenantQuerySchema
};
