/**
 * Department module validation schemas
 *
 * @module modules/department/schemas
 * @description Zod validation schemas for department endpoints.
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
 * Create department body validation
 * Used for POST /departments endpoint
 */
const createDepartmentSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  branch_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  short_name: z.string().trim().min(1).max(50).optional().nullable(),
  department_type: z.enum(['CLINICAL', 'ADMINISTRATIVE', 'SUPPORT', 'DIAGNOSTICS', 'OTHER']),
  is_active: z.boolean().optional()
});

/**
 * Update department body validation
 * Used for PUT /departments/:id endpoint
 * All fields optional for partial updates
 */
const updateDepartmentSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  branch_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  short_name: z.string().trim().min(1).max(50).optional().nullable(),
  department_type: z.enum(['CLINICAL', 'ADMINISTRATIVE', 'SUPPORT', 'DIAGNOSTICS', 'OTHER']).optional(),
  is_active: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Department ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const departmentIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List departments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with department-specific filters
 */
const listDepartmentsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  branch_id: uuidSchema.optional(),
  department_type: z.enum(['CLINICAL', 'ADMINISTRATIVE', 'SUPPORT', 'DIAGNOSTICS', 'OTHER']).optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createDepartmentSchema,
  updateDepartmentSchema,
  departmentIdParamsSchema,
  listDepartmentsQuerySchema
};
