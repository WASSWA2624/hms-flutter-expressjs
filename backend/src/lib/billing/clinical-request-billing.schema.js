/**
 * Shared Zod schema for clinical request-time billing payloads.
 *
 * @module lib/billing/clinical-request-billing.schema
 */

const { z } = require('zod');

const moneyValueSchema = z
  .union([z.number().nonnegative(), z.string().trim().min(1)])
  .transform((value) => {
    if (typeof value === 'number') {
      return value.toFixed(2);
    }
    return value;
  });

const clinicalRequestPriceSourceSchema = z.enum(['PHARMACY', 'FACILITY']);
const clinicalRequestPaymentModeSchema = z.enum(['SELF_PAY', 'INSURANCE']);
const clinicalRequestBillingEntitySchema = z.enum(['FACILITY', 'PHARMACY']);

const clinicalRequestBillingLineItemSchema = z.object({
  id: z.string().trim().min(1).max(80).optional().nullable(),
  label: z.string().trim().min(1).max(255),
  quantity: z.coerce.number().int().positive().optional().default(1),
  unit_price: moneyValueSchema.optional().nullable(),
  line_total: moneyValueSchema.optional().nullable(),
  price_source: clinicalRequestPriceSourceSchema.optional().nullable(),
  billing_entity: clinicalRequestBillingEntitySchema.optional().nullable(),
  payment_mode: clinicalRequestPaymentModeSchema.optional().nullable(),
  catalog_type: z
    .enum(['DRUG', 'LAB_TEST', 'LAB_PANEL', 'RADIOLOGY_TEST', 'CONSULTATION', 'SERVICE'])
    .optional()
    .nullable(),
  price_book_entry_id: z.string().trim().min(1).max(36).optional().nullable(),
  coverage_plan_id: z.string().trim().min(1).max(36).optional().nullable(),
  patient_share: moneyValueSchema.optional().nullable(),
  insurer_share: moneyValueSchema.optional().nullable(),
  copay_amount: moneyValueSchema.optional().nullable(),
});

const clinicalRequestPaymentStatusSchema = z.enum([
  'PAID',
  'PARTIAL',
  'PENDING',
  'NOT_BILLED',
  'NOT_REQUIRED',
  'NO_CHARGE',
]);

const clinicalRequestBillingSchema = z
  .object({
    payment_status: clinicalRequestPaymentStatusSchema.optional().default('NOT_BILLED'),
    currency: z.string().trim().min(3).max(10).optional().default('USD'),
    total_amount: moneyValueSchema.optional().nullable(),
    paid_amount: moneyValueSchema.optional().nullable(),
    line_amount: moneyValueSchema.optional().nullable(),
    payment_method: z.string().trim().min(1).max(40).optional().nullable(),
    payment_reference: z.string().trim().min(1).max(120).optional().nullable(),
    billing_entity: clinicalRequestBillingEntitySchema.optional().nullable(),
    payment_mode: clinicalRequestPaymentModeSchema.optional().nullable(),
    coverage_plan_id: z.string().trim().min(1).max(36).optional().nullable(),
    coverage_percentage: z.coerce.number().min(0).max(100).optional().nullable(),
    copay_type: z.enum(['NONE', 'FIXED', 'PERCENT']).optional().nullable(),
    copay_value: moneyValueSchema.optional().nullable(),
    patient_share: moneyValueSchema.optional().nullable(),
    insurer_share: moneyValueSchema.optional().nullable(),
    copay_amount: moneyValueSchema.optional().nullable(),
    line_items: z.array(clinicalRequestBillingLineItemSchema).max(500).optional().default([]),
  })
  .passthrough();

module.exports = {
  clinicalRequestBillingSchema,
  clinicalRequestBillingLineItemSchema,
  clinicalRequestPaymentStatusSchema,
  clinicalRequestPriceSourceSchema,
  clinicalRequestPaymentModeSchema,
  clinicalRequestBillingEntitySchema,
};
