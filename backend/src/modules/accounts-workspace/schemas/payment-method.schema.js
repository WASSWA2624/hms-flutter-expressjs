/**
 * Payment Methods schemas
 *
 * @module modules/accounts-workspace/schemas
 * @description Zod contracts for `Accounts & Finance → Setup & Controls →
 * Payment Methods`. `method_type` reuses the canonical `PaymentMethodType`
 * taxonomy that `payment.method` already stores. Public identifiers only; raw
 * database IDs never appear in requests or responses.
 */

const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const PAYMENT_METHOD_STATUSES = ['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'];
const PAYMENT_METHOD_ACTIONS = [
  'activate',
  'deactivate',
  'archive',
  'restore',
];

/** Canonical tender taxonomy, shared with `payment.method`. */
const PAYMENT_METHOD_TYPES = [
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
  'OTHER',
];

const PAYMENT_METHOD_DIRECTIONS = ['INCOMING', 'OUTGOING', 'BOTH'];

const PaymentMethodStatusEnum = z.enum(PAYMENT_METHOD_STATUSES);
const PaymentMethodTypeEnum = z.enum(PAYMENT_METHOD_TYPES);
const PaymentMethodDirectionEnum = z.enum(PAYMENT_METHOD_DIRECTIONS);

const isoDateSchema = z
  .string()
  .trim()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), {
    message: 'errors.validation.invalid_date',
  });

const optionalIsoDateSchema = isoDateSchema.nullable().optional();

/** Query booleans arrive as strings; accept the usual spellings. */
const queryBooleanSchema = z
  .enum(['true', 'false', '1', '0'])
  .optional()
  .transform((value) => {
    if (value == null) return undefined;
    return value === 'true' || value === '1';
  });

/** Comma-separated multi-select that also accepts a single value. */
const csvEnumSchema = (values) =>
  z
    .string()
    .trim()
    .optional()
    .transform((value) => {
      if (!value) return undefined;
      const parsed = value
        .split(',')
        .map((entry) => entry.trim().toUpperCase())
        .filter((entry) => values.includes(entry));
      return parsed.length ? parsed : undefined;
    });

const paymentMethodsQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  status: csvEnumSchema(PAYMENT_METHOD_STATUSES),
  method_type: csvEnumSchema(PAYMENT_METHOD_TYPES),
  direction: csvEnumSchema(PAYMENT_METHOD_DIRECTIONS),
  method_code: z.string().trim().max(32).optional(),
  method_name: z.string().trim().max(160).optional(),
  settlement_account_id: uuidOrFriendlyIdentifierSchema.optional(),
  clearing_account_id: uuidOrFriendlyIdentifierSchema.optional(),
  requires_external_reference: queryBooleanSchema,
  requires_approval: queryBooleanSchema,
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

const paymentMethodIdentifierParamsSchema = z.object({
  paymentMethodIdentifier: uuidOrFriendlyIdentifierSchema,
});

const paymentMethodActionParamsSchema = z.object({
  paymentMethodIdentifier: uuidOrFriendlyIdentifierSchema,
  action: z.enum(PAYMENT_METHOD_ACTIONS),
});

const paymentMethodBaseSchema = z.object({
  method_code: z.string().trim().min(1).max(32),
  method_name: z.string().trim().min(1).max(160),
  method_type: PaymentMethodTypeEnum,
  direction: PaymentMethodDirectionEnum,
  provider: z.string().trim().max(120).nullable().optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  settlement_account_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  clearing_account_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  requires_external_reference: z.boolean().optional(),
  requires_approval: z.boolean().optional(),
  fee_rule: z.string().trim().max(120).nullable().optional(),
  facility_scope: z.string().trim().max(120).nullable().optional(),
  effective_from: optionalIsoDateSchema,
  effective_to: optionalIsoDateSchema,
  notes: z.string().trim().max(500).nullable().optional(),
});

/** The effective window must stay in chronological order. */
const withDateOrdering = (schema) =>
  schema.superRefine((value, ctx) => {
    const at = (field) => {
      const raw = value?.[field];
      return raw ? Date.parse(raw) : null;
    };

    const from = at('effective_from');
    const to = at('effective_to');
    if (from !== null && to !== null && to < from) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['effective_to'],
        message: 'errors.accounts.payment_method.effective_to_before_from',
      });
    }
  });

const createPaymentMethodSchema = withDateOrdering(paymentMethodBaseSchema);

const updatePaymentMethodSchema = withDateOrdering(
  paymentMethodBaseSchema.partial().extend({
    version: z.coerce.number().int().min(1).optional(),
  })
);

const paymentMethodActionSchema = z.object({
  reason: z.string().trim().min(1).max(500).optional(),
  version: z.coerce.number().int().min(1).optional(),
});

module.exports = {
  PAYMENT_METHOD_STATUSES,
  PAYMENT_METHOD_ACTIONS,
  PAYMENT_METHOD_TYPES,
  PAYMENT_METHOD_DIRECTIONS,
  PaymentMethodStatusEnum,
  PaymentMethodTypeEnum,
  PaymentMethodDirectionEnum,
  paymentMethodsQuerySchema,
  paymentMethodIdentifierParamsSchema,
  paymentMethodActionParamsSchema,
  createPaymentMethodSchema,
  updatePaymentMethodSchema,
  paymentMethodActionSchema,
};
