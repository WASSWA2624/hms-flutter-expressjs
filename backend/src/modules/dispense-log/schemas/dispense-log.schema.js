/**
 * Dispense Log module validation schemas
 *
 * @module modules/dispense-log/schemas
 * @description Zod validation schemas for dispense log endpoints.
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
 * Create dispense log body validation
 * Used for POST /dispense-logs endpoint
 */
const createDispenseLogSchema = z.object({
  pharmacy_order_item_id: uuidSchema,
  status: z.enum(['PENDING', 'DISPENSED', 'RETURNED', 'CANCELLED']),
  dispensed_at: isoDateSchema.optional().nullable(),
  quantity_dispensed: z.number().int().min(0).default(0)
});

/**
 * Update dispense log body validation
 * Used for PUT /dispense-logs/:id endpoint
 * All fields optional for partial updates
 */
const updateDispenseLogSchema = z.object({
  status: z.enum(['PENDING', 'DISPENSED', 'RETURNED', 'CANCELLED']).optional(),
  dispensed_at: isoDateSchema.optional().nullable(),
  quantity_dispensed: z.number().int().min(0).optional()
});

// ==================== URL Params ====================

/**
 * Dispense log ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const dispenseLogIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List dispense logs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with dispense log-specific filters
 */
const listDispenseLogsQuerySchema = listQuerySchema.extend({
  pharmacy_order_item_id: uuidSchema.optional(),
  status: z.enum(['PENDING', 'DISPENSED', 'RETURNED', 'CANCELLED']).optional(),
  dispensed_at_from: isoDateSchema.optional(),
  dispensed_at_to: isoDateSchema.optional()
});

module.exports = {
  createDispenseLogSchema,
  updateDispenseLogSchema,
  dispenseLogIdParamsSchema,
  listDispenseLogsQuerySchema
};
