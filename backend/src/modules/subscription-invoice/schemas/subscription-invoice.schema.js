/**
 * Subscription Invoice module validation schemas
 *
 * @module modules/subscription-invoice/schemas
 * @description Zod validation schemas for subscription invoice endpoints.
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
 * Create subscription invoice body validation
 * Used for POST /subscription-invoices endpoint
 */
const createSubscriptionInvoiceSchema = z.object({
  subscription_id: uuidOrFriendlyIdentifierSchema,
  invoice_id: uuidOrFriendlyIdentifierSchema
});

/**
 * Update subscription invoice body validation
 * Used for PUT /subscription-invoices/:id endpoint
 * All fields optional for partial updates
 */
const updateSubscriptionInvoiceSchema = z.object({
  subscription_id: uuidOrFriendlyIdentifierSchema.optional(),
  invoice_id: uuidOrFriendlyIdentifierSchema.optional()
});

const collectSubscriptionInvoiceSchema = z.object({
  payment_method: z.enum([
    'CASH',
    'CREDIT_CARD',
    'DEBIT_CARD',
    'PREPAID_CARD',
    'GIFT_CARD',
    'VOUCHER',
    'BANK_CHECK',
    'MOBILE_MONEY',
    'BANK_TRANSFER',
    'INSURANCE',
    'OTHER'
  ]).optional(),
  notes: z.string().trim().max(10000).optional().nullable()
});

const retrySubscriptionInvoiceSchema = z.object({
  retry_reason: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Subscription Invoice ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const subscriptionInvoiceIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List subscription invoices query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with subscription invoice-specific filters
 */
const listSubscriptionInvoicesQuerySchema = listQuerySchema.extend({
  subscription_id: uuidOrFriendlyIdentifierSchema.optional(),
  invoice_id: uuidOrFriendlyIdentifierSchema.optional()
});

module.exports = {
  createSubscriptionInvoiceSchema,
  updateSubscriptionInvoiceSchema,
  collectSubscriptionInvoiceSchema,
  retrySubscriptionInvoiceSchema,
  subscriptionInvoiceIdParamsSchema,
  listSubscriptionInvoicesQuerySchema
};
