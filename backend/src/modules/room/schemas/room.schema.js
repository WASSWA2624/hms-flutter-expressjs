/**
 * Room module validation schemas
 *
 * @module modules/room/schemas
 * @description Zod validation schemas for room endpoints.
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
 * Create room body validation
 * Used for POST /rooms endpoint
 */
const createRoomSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema,
  ward_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  floor: z.string().trim().min(1).max(50).optional().nullable()
});

/**
 * Update room body validation
 * Used for PUT /rooms/:id endpoint
 * All fields optional for partial updates
 */
const updateRoomSchema = z.object({
  facility_id: uuidSchema.optional(),
  ward_id: uuidSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  floor: z.string().trim().min(1).max(50).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Room ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const roomIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List rooms query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with room-specific filters
 */
const listRoomsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  ward_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRoomSchema,
  updateRoomSchema,
  roomIdParamsSchema,
  listRoomsQuerySchema
};
