/**
 * User module validation schemas
 *
 * @module modules/user/schemas
 * @description Zod validation schemas for user endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const userStatusSchema = z.enum(['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING']);
const permissionIdsSchema = z.array(uuidSchema).max(100).optional();

// ==================== Body Schemas ====================

/**
 * Create user body validation
 * Used for POST /users endpoint
 */
const createUserSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  position_title: z.string().trim().min(1).max(120),
  email: z.string().trim().email().max(255),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  password: z.string().trim().min(8).max(255).optional(),
  password_hash: z.string().trim().min(1).max(255).optional(),
  status: userStatusSchema,
  permission_ids: permissionIdsSchema,
}).refine((value) => Boolean(value.password || value.password_hash), {
  message: 'errors.validation.field.required',
  path: ['password'],
});

/**
 * Update user body validation
 * Used for PUT /users/:id endpoint
 * All fields optional for partial updates
 */
const updateUserSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  position_title: z.string().trim().min(1).max(120).optional(),
  email: z.string().trim().email().max(255).optional(),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  password: z.string().trim().min(8).max(255).optional(),
  password_hash: z.string().trim().min(1).max(255).optional(),
  status: userStatusSchema.optional(),
  permission_ids: permissionIdsSchema,
});

// ==================== URL Params ====================

/**
 * User ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const userIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List users query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with user-specific filters
 */
const listUsersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  position_title: z.string().trim().optional(),
  email: z.string().trim().optional(),
  status: userStatusSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createUserSchema,
  updateUserSchema,
  userIdParamsSchema,
  listUsersQuerySchema
};
