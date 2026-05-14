/**
 * Role-Permission module validation schemas
 *
 * @module modules/role-permission/schemas
 * @description Zod validation schemas for role-permission endpoints.
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
 * Create role-permission body validation
 * Used for POST /role-permissions endpoint
 */
const createRolePermissionSchema = z.object({
  role_id: uuidSchema,
  permission_id: uuidSchema
});

/**
 * Update role-permission body validation
 * Used for PUT /role-permissions/:id endpoint
 * All fields optional for partial updates
 */
const updateRolePermissionSchema = z.object({
  role_id: uuidSchema.optional(),
  permission_id: uuidSchema.optional()
});

// ==================== URL Params ====================

/**
 * Role-Permission ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const rolePermissionIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List role-permissions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with role-permission-specific filters
 */
const listRolePermissionsQuerySchema = listQuerySchema.extend({
  role_id: uuidSchema.optional(),
  permission_id: uuidSchema.optional()
});

module.exports = {
  createRolePermissionSchema,
  updateRolePermissionSchema,
  rolePermissionIdParamsSchema,
  listRolePermissionsQuerySchema
};
