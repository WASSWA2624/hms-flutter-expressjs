/**
 * Permission module validation schemas
 *
 * @module modules/permission/schemas
 * @description Zod validation schemas for permission endpoints.
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
 * Create permission body validation
 * Used for POST /permissions endpoint
 */
const createPermissionSchema = z.object({
  tenant_id: uuidSchema,
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().min(1).max(255).optional().nullable()
});

/**
 * Update permission body validation
 * Used for PUT /permissions/:id endpoint
 * All fields optional for partial updates
 */
const updatePermissionSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().min(1).max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Permission ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const permissionIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List permissions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with permission-specific filters
 */
const listPermissionsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  name: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPermissionSchema,
  updatePermissionSchema,
  permissionIdParamsSchema,
  listPermissionsQuerySchema
};
