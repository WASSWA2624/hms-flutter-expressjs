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

// ==================== Body Schemas ====================

/**
 * Create role body validation
 * Used for POST /roles endpoint
 */
const permissionIdsSchema = z
  .array(uuidOrFriendlyIdentifierSchema)
  .max(500)
  .optional();

const createRoleSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120),
  display_name: z.string().trim().min(1).max(160),
  description: z.string().trim().min(1).max(255).optional().nullable(),
  permission_ids: permissionIdsSchema,
  confirm_similar: optionalBooleanSchema
});

/**
 * Update role body validation
 * Used for PUT /roles/:id endpoint
 * All fields optional for partial updates
 */
const updateRoleSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120).optional(),
  display_name: z.string().trim().min(1).max(160).optional().nullable(),
  description: z.string().trim().min(1).max(255).optional().nullable(),
  permission_ids: permissionIdsSchema,
  confirm_similar: optionalBooleanSchema
});

// ==================== URL Params ====================

/**
 * Role ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const roleIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List roles query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with role-specific filters
 */
const listRolesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRoleSchema,
  updateRoleSchema,
  roleIdParamsSchema,
  listRolesQuerySchema
};
