/**
 * Ward module validation schemas
 *
 * @module modules/ward/schemas
 * @description Zod validation schemas for ward endpoints.
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
 * Create ward body validation
 * Used for POST /wards endpoint
 */
const createWardSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema,
  department_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  ward_type: z.enum(['GENERAL', 'ICU', 'MATERNITY', 'PEDIATRIC', 'SURGICAL', 'OTHER']),
  is_active: z.boolean().optional()
});

/**
 * Update ward body validation
 * Used for PUT /wards/:id endpoint
 * All fields optional for partial updates
 */
const updateWardSchema = z.object({
  facility_id: uuidSchema.optional(),
  department_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  ward_type: z.enum(['GENERAL', 'ICU', 'MATERNITY', 'PEDIATRIC', 'SURGICAL', 'OTHER']).optional(),
  is_active: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Ward ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const wardIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List wards query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with ward-specific filters
 */
const listWardsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  department_id: uuidSchema.optional(),
  ward_type: z.enum(['GENERAL', 'ICU', 'MATERNITY', 'PEDIATRIC', 'SURGICAL', 'OTHER']).optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createWardSchema,
  updateWardSchema,
  wardIdParamsSchema,
  listWardsQuerySchema
};
