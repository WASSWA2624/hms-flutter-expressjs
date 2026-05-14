/**
 * Unit module validation schemas
 *
 * @module modules/unit/schemas
 * @description Zod validation schemas for unit endpoints.
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
 * Create unit body validation
 * Used for POST /units endpoint
 */
const createUnitSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  department_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  is_active: z.boolean().optional()
});

/**
 * Update unit body validation
 * Used for PUT /units/:id endpoint
 * All fields optional for partial updates
 */
const updateUnitSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  department_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  is_active: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Unit ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const unitIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List units query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with unit-specific filters
 */
const listUnitsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  department_id: uuidSchema.optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createUnitSchema,
  updateUnitSchema,
  unitIdParamsSchema,
  listUnitsQuerySchema
};
