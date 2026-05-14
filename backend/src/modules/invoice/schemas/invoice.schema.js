/**
 * Invoice module validation schemas
 *
 * @module modules/invoice/schemas
 * @description Zod validation schemas for invoice endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema,
  decimalStringSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create invoice body validation
 * Used for POST /invoices endpoint
 */
const createInvoiceSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED']),
  billing_status: z.enum(['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED']).default('DRAFT'),
  total_amount: decimalStringSchema,
  currency: z.string().trim().min(1).max(10),
  issued_at: z.string().datetime().optional()
});

/**
 * Update invoice body validation
 * Used for PUT /invoices/:id endpoint
 * All fields optional for partial updates
 */
const updateInvoiceSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED']).optional(),
  billing_status: z.enum(['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED']).optional(),
  total_amount: decimalStringSchema.optional(),
  currency: z.string().trim().min(1).max(10).optional(),
  issued_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Invoice ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const invoiceIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List invoices query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with invoice-specific filters
 */
const listInvoicesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED']).optional(),
  billing_status: z.enum(['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createInvoiceSchema,
  updateInvoiceSchema,
  invoiceIdParamsSchema,
  listInvoicesQuerySchema
};
