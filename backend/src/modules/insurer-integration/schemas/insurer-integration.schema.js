/**
 * Insurer Integration module validation schemas
 *
 * @module modules/insurer-integration/schemas
 * @description Zod validation schemas for insurer integration endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

const InsurerAdapterTypeEnum = z.enum(['STUB', 'GENERIC_REST']);

// ==================== Body Schemas ====================

/**
 * Create insurer integration body validation
 * Used for POST /insurer-integrations endpoint
 */
const createInsurerIntegrationSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120),
  adapter_type: InsurerAdapterTypeEnum.optional().default('STUB'),
  base_url: z.string().trim().max(500).optional().nullable(),
  is_enabled: z.boolean().optional().default(false),
  credentials_encrypted: z.string().optional().nullable(),
  config_json: z.any().optional().nullable(),
  webhook_secret_hash: z.string().trim().max(255).optional().nullable()
});

/**
 * Update insurer integration body validation
 * Used for PUT /insurer-integrations/:id endpoint
 * All fields optional for partial updates
 */
const updateInsurerIntegrationSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120).optional(),
  adapter_type: InsurerAdapterTypeEnum.optional(),
  base_url: z.string().trim().max(500).optional().nullable(),
  is_enabled: z.boolean().optional(),
  credentials_encrypted: z.string().optional().nullable(),
  config_json: z.any().optional().nullable(),
  webhook_secret_hash: z.string().trim().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Insurer Integration ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const insurerIntegrationIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List insurer integrations query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with insurer integration-specific filters
 */
const listInsurerIntegrationsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  adapter_type: InsurerAdapterTypeEnum.optional(),
  is_enabled: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createInsurerIntegrationSchema,
  updateInsurerIntegrationSchema,
  insurerIntegrationIdParamsSchema,
  listInsurerIntegrationsQuerySchema,
  InsurerAdapterTypeEnum
};
