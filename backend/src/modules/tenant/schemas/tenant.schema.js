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
  uuidSchema, 
  listQuerySchema 
} = require('@lib/validation/zod');

const extensionJsonSchema = z.record(z.string(), z.unknown()).optional().nullable();

// ==================== Body Schemas ====================

/**
 * Create tenant body validation
 * Used for POST /tenants endpoint
 */
const createTenantSchema = z.object({
  name: z.string().trim().min(1).max(255),
  slug: z.string().trim().min(1).max(191).optional(),
  is_active: z.boolean().optional(),
  extension_json: extensionJsonSchema,
});

/**
 * Update tenant body validation
 * Used for PUT /tenants/:id endpoint
 * All fields optional for partial updates
 */
const updateTenantSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  slug: z.string().trim().min(1).max(191).optional().nullable(),
  is_active: z.boolean().optional(),
  extension_json: extensionJsonSchema,
});

// ==================== URL Params ====================

/**
 * Tenant ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const tenantIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List tenants query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with tenant-specific filters
 */
const listTenantsQuerySchema = listQuerySchema.extend({
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createTenantSchema,
  updateTenantSchema,
  tenantIdParamsSchema,
  listTenantsQuerySchema
};
