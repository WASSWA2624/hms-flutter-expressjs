/**
 * Staff position module validation schemas
 *
 * @module modules/staff-position/schemas
 * @description Zod validation schemas for staff position endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create staff position body validation
 * Used for POST /staff-positions endpoint
 */
const createStaffPositionSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().max(255).optional().nullable(),
  is_active: z.boolean().optional()
});

/**
 * Update staff position body validation
 * Used for PUT /staff-positions/:id endpoint
 * All fields optional for partial updates
 */
const updateStaffPositionSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(255).optional().nullable(),
  is_active: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Staff position ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const staffPositionIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List staff positions query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with staff-position-specific filters
 */
const listStaffPositionsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  is_active: z.string().transform((val) => val === 'true').optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createStaffPositionSchema,
  updateStaffPositionSchema,
  staffPositionIdParamsSchema,
  listStaffPositionsQuerySchema
};
