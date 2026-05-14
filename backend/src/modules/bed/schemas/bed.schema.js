/**
 * Bed module validation schemas
 *
 * @module modules/bed/schemas
 * @description Zod validation schemas for bed endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidSchema,
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create bed body validation
 * Used for POST /beds endpoint
 */
const createBedSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema,
  ward_id: uuidSchema,
  room_id: uuidSchema.optional().nullable(),
  label: z.string().trim().min(1).max(50),
  status: z.enum(['AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE'])
});

/**
 * Update bed body validation
 * Used for PUT /beds/:id endpoint
 * All fields optional for partial updates
 */
const updateBedSchema = z.object({
  facility_id: uuidSchema.optional(),
  ward_id: uuidSchema.optional(),
  room_id: uuidSchema.optional().nullable(),
  label: z.string().trim().min(1).max(50).optional(),
  status: z.enum(['AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE']).optional()
});

// ==================== URL Params ====================

/**
 * Bed ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const bedIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List beds query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with bed-specific filters
 */
const listBedsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  ward_id: uuidOrFriendlyIdentifierSchema.optional(),
  room_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createBedSchema,
  updateBedSchema,
  bedIdParamsSchema,
  listBedsQuerySchema
};
