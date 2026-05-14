/**
 * Procedure module validation schemas
 *
 * @module modules/procedure/schemas
 * @description Zod validation schemas for procedure endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create procedure body validation
 * Used for POST /procedures endpoint
 */
const createProcedureSchema = z.object({
  encounter_id: uuidSchema,
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(65535),
  performed_at: isoDateSchema.optional().nullable()
});

/**
 * Update procedure body validation
 * Used for PUT /procedures/:id endpoint
 * All fields optional for partial updates
 */
const updateProcedureSchema = z.object({
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(65535).optional(),
  performed_at: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * Procedure ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const procedureIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List procedures query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with procedure-specific filters
 */
const listProceduresQuerySchema = listQuerySchema.extend({
  encounter_id: uuidSchema.optional(),
  code: z.string().trim().optional()
});

module.exports = {
  createProcedureSchema,
  updateProcedureSchema,
  procedureIdParamsSchema,
  listProceduresQuerySchema
};
