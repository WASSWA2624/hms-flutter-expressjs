/**
 * Refund module validation schemas
 *
 * @module modules/refund/schemas
 * @description Zod validation schemas for refund endpoints.
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  decimalStringSchema,
} = require('@lib/validation/zod');

/**
 * Create refund body validation
 */
const createRefundSchema = z.object({
  payment_id: uuidOrFriendlyIdentifierSchema,
  amount: decimalStringSchema,
  refunded_at: z.string().datetime().optional(),
  reason: z.string().trim().max(255).optional().nullable()
});

/**
 * Update refund body validation
 */
const updateRefundSchema = z.object({
  payment_id: uuidOrFriendlyIdentifierSchema.optional(),
  amount: decimalStringSchema.optional(),
  refunded_at: z.string().datetime().optional(),
  reason: z.string().trim().max(255).optional().nullable()
});

/**
 * Refund ID URL parameter validation
 */
const refundIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

/**
 * List refunds query validation
 */
const listRefundsQuerySchema = listQuerySchema.extend({
  payment_id: uuidOrFriendlyIdentifierSchema.optional(),
  refunded_at_from: z.string().datetime().optional(),
  refunded_at_to: z.string().datetime().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createRefundSchema,
  updateRefundSchema,
  refundIdParamsSchema,
  listRefundsQuerySchema
};
