/**
 * Accounts Invoice validation schemas.
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
} = require('@lib/validation/zod');

const AccountsInvoiceStatusEnum = z.enum(['DRAFT', 'ISSUED', 'VOIDED']);

const lineItemSchema = z.object({
  name: z.string().trim().min(1).max(255),
  description: z.string().trim().max(500).optional().nullable(),
  quantity: z.coerce.number().positive(),
  unit_price: z.coerce.number().min(0),
});

const createAccountsInvoiceSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  payee: z.string().trim().min(1).max(255),
  invoice_date: z.string().datetime().or(z.string().min(4)),
  reference: z.string().trim().max(120).optional().nullable(),
  notes: z.string().trim().max(500).optional().nullable(),
  currency: z.string().trim().min(1).max(10).toUpperCase().optional().default('UGX'),
  status: AccountsInvoiceStatusEnum.optional().default('DRAFT'),
  items: z.array(lineItemSchema).min(1),
});

const updateAccountsInvoiceSchema = z.object({
  payee: z.string().trim().min(1).max(255).optional(),
  invoice_date: z.string().datetime().or(z.string().min(4)).optional(),
  reference: z.string().trim().max(120).optional().nullable(),
  notes: z.string().trim().max(500).optional().nullable(),
  currency: z.string().trim().min(1).max(10).toUpperCase().optional(),
  status: z.enum(['DRAFT', 'ISSUED']).optional(),
  items: z.array(lineItemSchema).min(1).optional(),
});

const voidAccountsInvoiceSchema = z.object({
  reason: z.string().trim().min(1).max(500),
  notes: z.string().trim().max(500).optional().nullable(),
});

const accountsInvoiceIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listAccountsInvoicesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: AccountsInvoiceStatusEnum.optional(),
  search: z.string().trim().optional(),
  date_from: z.string().optional(),
  date_to: z.string().optional(),
});

module.exports = {
  createAccountsInvoiceSchema,
  updateAccountsInvoiceSchema,
  voidAccountsInvoiceSchema,
  accountsInvoiceIdParamsSchema,
  listAccountsInvoicesQuerySchema,
  AccountsInvoiceStatusEnum,
};
