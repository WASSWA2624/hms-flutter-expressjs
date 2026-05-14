/**
 * PHI access log module validation schemas
 *
 * @module modules/phi-access-log/schemas
 * @description Zod validation schemas for PHI access log endpoints.
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
 * Create PHI access log body validation
 * Used for POST /phi-access-logs endpoint
 */
const createPhiAccessLogSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema,
  access_scope: z.enum(['TENANT', 'FACILITY', 'DEPARTMENT', 'PATIENT']),
  reason: z.string().trim().max(255).optional().nullable(),
});

/**
 * Update PHI access log body validation
 * Used for PUT /phi-access-logs/:id endpoint
 * All fields optional for partial updates
 */
const updatePhiAccessLogSchema = z.object({
  access_scope: z.enum(['TENANT', 'FACILITY', 'DEPARTMENT', 'PATIENT']).optional(),
  reason: z.string().trim().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * PHI access log ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const phiAccessLogIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

/**
 * User ID URL parameter validation
 * Used for GET /user/:userId endpoint
 */
const userIdParamsSchema = z.object({
  userId: uuidOrFriendlyIdentifierSchema,
});

// ==================== Query Params ====================

/**
 * List PHI access logs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with phi-access-log-specific filters
 */
const listPhiAccessLogsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  user_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  access_scope: z.enum(['TENANT', 'FACILITY', 'DEPARTMENT', 'PATIENT']).optional(),
  search: z.string().trim().max(120).optional(),
  date_from: z.string().datetime().optional(),
  date_to: z.string().datetime().optional(),
});

module.exports = {
  createPhiAccessLogSchema,
  updatePhiAccessLogSchema,
  phiAccessLogIdParamsSchema,
  userIdParamsSchema,
  listPhiAccessLogsQuerySchema
};
