const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
  decimalStringSchema,
} = require('@lib/validation/zod');

const queueTypeSchema = z.enum([
  'NEEDS_ISSUE',
  'PENDING_PAYMENT',
  'CLAIMS_PENDING',
  'APPROVAL_REQUIRED',
  'OVERDUE',
]);

const signedDecimalStringSchema = z
  .string()
  .trim()
  .regex(/^-?\d+(\.\d{1,2})?$/, 'Must be a valid decimal number with up to 2 decimal places');

const workspaceQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  search: z.string().trim().optional(),
});

const workItemsQuerySchema = listQuerySchema.extend({
  queue: queueTypeSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const patientLedgerParamsSchema = z.object({
  patientIdentifier: uuidOrFriendlyIdentifierSchema,
});

const patientLedgerQuerySchema = listQuerySchema.extend({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

const invoiceIdentifierParamsSchema = z.object({
  invoiceIdentifier: uuidOrFriendlyIdentifierSchema,
});

const paymentIdentifierParamsSchema = z.object({
  paymentIdentifier: uuidOrFriendlyIdentifierSchema,
});

const approvalIdentifierParamsSchema = z.object({
  approvalIdentifier: uuidOrFriendlyIdentifierSchema,
});

const issueInvoiceSchema = z.object({
  issued_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const sendInvoiceSchema = z.object({
  recipient_email: z.string().trim().email().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const voidRequestSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const reconcilePaymentSchema = z.object({
  status: z.enum(['COMPLETED', 'FAILED', 'REFUNDED']).optional(),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const refundRequestSchema = z.object({
  amount: decimalStringSchema.optional(),
  reason: z.string().trim().min(2).max(255),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const adjustmentRequestSchema = z.object({
  invoice_id: uuidOrFriendlyIdentifierSchema,
  amount: signedDecimalStringSchema,
  reason: z.string().trim().min(2).max(255),
  status: z.enum(['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED']).optional(),
  adjusted_at: z.string().datetime().optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable(),
});

const approveApprovalSchema = z.object({
  decision_notes: z.string().trim().max(10000).optional().nullable(),
});

const rejectApprovalSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  decision_notes: z.string().trim().max(10000).optional().nullable(),
});

module.exports = {
  queueTypeSchema,
  workspaceQuerySchema,
  workItemsQuerySchema,
  patientLedgerParamsSchema,
  patientLedgerQuerySchema,
  invoiceIdentifierParamsSchema,
  paymentIdentifierParamsSchema,
  approvalIdentifierParamsSchema,
  issueInvoiceSchema,
  sendInvoiceSchema,
  voidRequestSchema,
  reconcilePaymentSchema,
  refundRequestSchema,
  adjustmentRequestSchema,
  approveApprovalSchema,
  rejectApprovalSchema,
};
