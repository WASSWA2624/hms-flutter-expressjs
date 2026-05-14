/**
 * System change log module validation schemas
 *
 * @module modules/system-change-log/schemas
 * @description Zod validation schemas for system change log endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create system change log body validation
 * Used for POST /system-change-logs endpoint
 */
const createSystemChangeLogSchema = z.object({
  change_type: z.string().trim().min(1).max(120),
  details: z.string().trim().optional().nullable()
});

/**
 * Update system change log body validation
 * Used for PUT /system-change-logs/:id endpoint
 * All fields optional for partial updates
 */
const updateSystemChangeLogSchema = z.object({
  change_type: z.string().trim().min(1).max(120).optional(),
  details: z.string().trim().optional().nullable()
});

/**
 * Approve system change log body validation
 * Used for POST /system-change-logs/:id/approve endpoint
 */
const approveSystemChangeLogSchema = z.object({
  approval_notes: z.string().trim().optional().nullable()
});

/**
 * Implement system change log body validation
 * Used for POST /system-change-logs/:id/implement endpoint
 */
const implementSystemChangeLogSchema = z.object({
  implementation_notes: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * System change log ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, POST /:id/approve, and POST /:id/implement endpoints
 */
const systemChangeLogIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

// ==================== Query Params ====================

/**
 * List system change logs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with system-change-log-specific filters
 */
const listSystemChangeLogsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  change_type: z.string().trim().optional(),
  search: z.string().trim().max(120).optional(),
  from_date: z.string().datetime().optional(),
  to_date: z.string().datetime().optional(),
});

module.exports = {
  createSystemChangeLogSchema,
  updateSystemChangeLogSchema,
  approveSystemChangeLogSchema,
  implementSystemChangeLogSchema,
  systemChangeLogIdParamsSchema,
  listSystemChangeLogsQuerySchema
};
