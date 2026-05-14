/**
 * License module validation schemas
 *
 * @module modules/license/schemas
 * @description Zod validation schemas for license endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema 
} = require('@lib/validation/zod');

// Enums from Prisma schema
const LicenseTypeEnum = z.enum(['PER_USER', 'PER_FACILITY', 'ENTERPRISE']);
const SubscriptionStatusEnum = z.enum(['ACTIVE', 'PAST_DUE', 'CANCELLED', 'TRIAL']);

// ==================== Body Schemas ====================

/**
 * Create license body validation
 * Used for POST /licenses endpoint
 */
const createLicenseSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  license_type: LicenseTypeEnum,
  status: SubscriptionStatusEnum,
  issued_at: z.string().datetime().optional(),
  expires_at: z.string().datetime().optional().nullable()
});

/**
 * Update license body validation
 * Used for PUT /licenses/:id endpoint
 * All fields optional for partial updates
 */
const updateLicenseSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  license_type: LicenseTypeEnum.optional(),
  status: SubscriptionStatusEnum.optional(),
  issued_at: z.string().datetime().optional(),
  expires_at: z.string().datetime().optional().nullable()
});

// ==================== URL Params ====================

/**
 * License ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const licenseIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List licenses query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with license-specific filters
 */
const listLicensesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  license_type: LicenseTypeEnum.optional(),
  status: SubscriptionStatusEnum.optional()
});

module.exports = {
  createLicenseSchema,
  updateLicenseSchema,
  licenseIdParamsSchema,
  listLicensesQuerySchema
};
