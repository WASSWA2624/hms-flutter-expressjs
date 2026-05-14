/**
 * User-Role module validation schemas
 *
 * @module modules/user-role/schemas
 * @description Zod validation schemas for user-role endpoints.
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
 * Create user-role body validation
 * Used for POST /user-roles endpoint
 */
const createUserRoleSchema = z.object({
  user_id: uuidSchema,
  role_id: uuidSchema,
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable()
});

/**
 * Update user-role body validation
 * Used for PUT /user-roles/:id endpoint
 * All fields optional for partial updates
 */
const updateUserRoleSchema = z.object({
  user_id: uuidSchema.optional(),
  role_id: uuidSchema.optional(),
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * User-Role ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const userRoleIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List user-roles query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with user-role-specific filters
 */
const listUserRolesQuerySchema = listQuerySchema.extend({
  user_id: uuidSchema.optional(),
  role_id: uuidSchema.optional(),
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional()
});

module.exports = {
  createUserRoleSchema,
  updateUserRoleSchema,
  userRoleIdParamsSchema,
  listUserRolesQuerySchema
};
