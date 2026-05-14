/**
 * Invoice item module validation schemas
 *
 * @module modules/invoice-item/schemas
 * @description Zod validation schemas for invoice item endpoints.
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  decimalStringSchema,
} = require('@lib/validation/zod');

/**
 * Create invoice item body validation
 */
const createInvoiceItemSchema = z.object({
  invoice_id: uuidOrFriendlyIdentifierSchema,
  description: z.string().trim().min(1).max(255),
  quantity: z.coerce.number().int().positive().optional(),
  unit_price: decimalStringSchema,
  total_price: decimalStringSchema
});

/**
 * Update invoice item body validation
 */
const updateInvoiceItemSchema = z.object({
  invoice_id: uuidOrFriendlyIdentifierSchema.optional(),
  description: z.string().trim().min(1).max(255).optional(),
  quantity: z.coerce.number().int().positive().optional(),
  unit_price: decimalStringSchema.optional(),
  total_price: decimalStringSchema.optional()
});

/**
 * Invoice item ID URL parameter validation
 */
const invoiceItemIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

/**
 * List invoice items query validation
 */
const listInvoiceItemsQuerySchema = listQuerySchema.extend({
  invoice_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createInvoiceItemSchema,
  updateInvoiceItemSchema,
  invoiceItemIdParamsSchema,
  listInvoiceItemsQuerySchema
};
