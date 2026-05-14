/**
 * Branch module validation schemas
 *
 * @module modules/branch/schemas
 * @description Zod validation schemas for branch endpoints.
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
 * Create branch body validation
 * Used for POST /branches endpoint
 */
const createBranchSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  is_active: z.boolean().optional()
});

/**
 * Update branch body validation
 * Used for PUT /branches/:id endpoint
 * All fields optional for partial updates
 */
const updateBranchSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  is_active: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Branch ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const branchIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List branches query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with branch-specific filters
 */
const listBranchesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createBranchSchema,
  updateBranchSchema,
  branchIdParamsSchema,
  listBranchesQuerySchema
};
