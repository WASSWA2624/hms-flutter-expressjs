/**
 * Role module validation schemas
 *
 * @module modules/role/schemas
 * @description Zod validation schemas for role endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create role body validation
 * Used for POST /roles endpoint
 */
const createRoleSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().min(1).max(255).optional().nullable()
});

/**
 * Update role body validation
 * Used for PUT /roles/:id endpoint
 * All fields optional for partial updates
 */
const updateRoleSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().min(1).max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Role ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const roleIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List roles query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with role-specific filters
 */
const listRolesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  name: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRoleSchema,
  updateRoleSchema,
  roleIdParamsSchema,
  listRolesQuerySchema
};
