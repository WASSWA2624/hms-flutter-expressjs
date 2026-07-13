/**
 * Insurance Company module validation schemas
 *
 * @module modules/insurance-company/schemas
 * @description Zod validation schemas for insurance company endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const contactJsonSchema = z.object({}).passthrough();

// ==================== Body Schemas ====================

/**
 * Create insurance company body validation
 * Used for POST /insurance-companies endpoint
 */
const createInsuranceCompanySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().min(1).max(64),
  contact_json: contactJsonSchema.optional().nullable(),
  is_active: z.boolean().optional().default(true),
  notes: z.string().trim().max(255).optional().nullable()
});

/**
 * Update insurance company body validation
 * Used for PUT /insurance-companies/:id endpoint
 * All fields optional for partial updates
 */
const updateInsuranceCompanySchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: z.string().trim().min(1).max(64).optional(),
  contact_json: contactJsonSchema.optional().nullable(),
  is_active: z.boolean().optional(),
  notes: z.string().trim().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Insurance Company ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and GET /:id/schemes endpoints
 */
const insuranceCompanyIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List insurance companies query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with insurance company-specific filters
 */
const listInsuranceCompaniesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  code: z.string().trim().max(64).optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createInsuranceCompanySchema,
  updateInsuranceCompanySchema,
  insuranceCompanyIdParamsSchema,
  listInsuranceCompaniesQuerySchema
};
