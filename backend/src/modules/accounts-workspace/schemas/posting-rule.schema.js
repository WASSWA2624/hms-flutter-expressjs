/**
 * Posting Rules schemas
 *
 * @module modules/accounts-workspace/schemas
 * @description Zod contracts for `Accounts & Finance → Setup & Controls →
 * Posting Rules`. Public identifiers only; raw database IDs never appear in
 * requests or responses.
 */

const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const POSTING_RULE_STATUSES = ['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'];
const POSTING_RULE_TEST_STATUSES = ['NOT_TESTED', 'PASSED', 'FAILED'];
const POSTING_RULE_ACTIONS = ['activate', 'deactivate', 'archive', 'restore'];

/**
 * Controlled event vocabulary. Stored as text so a new event does not need a
 * migration, but only these values are accepted.
 */
const POSTING_RULE_EVENT_TYPES = [
  'CHARGE_POSTED',
  'INVOICE_ISSUED',
  'PAYMENT_RECEIVED',
  'REFUND_ISSUED',
  'CREDIT_NOTE_ISSUED',
  'WRITE_OFF',
  'CLAIM_SUBMITTED',
  'CLAIM_SETTLED',
  'STOCK_ISSUED',
  'STOCK_RECEIVED',
  'PAYROLL_POSTED',
  'ADJUSTMENT',
];

const PostingRuleStatusEnum = z.enum(POSTING_RULE_STATUSES);
const PostingRuleEventTypeEnum = z.enum(POSTING_RULE_EVENT_TYPES);

const isoDateSchema = z
  .string()
  .trim()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), {
    message: 'errors.validation.invalid_date',
  });

const optionalIsoDateSchema = isoDateSchema.nullable().optional();

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

/** Hierarchical multi-select posts a comma-separated list of free-text nodes. */
const csvTextSchema = z
  .string()
  .trim()
  .max(500)
  .optional()
  .transform((value) => {
    if (!value) return undefined;
    const parsed = value
      .split(',')
      .map((entry) => entry.trim())
      .filter(Boolean);
    return parsed.length ? parsed : undefined;
  });

const postingRulesQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  status: csvEnumSchema(POSTING_RULE_STATUSES),
  test_status: csvEnumSchema(POSTING_RULE_TEST_STATUSES),
  event_type: csvEnumSchema(POSTING_RULE_EVENT_TYPES),
  source_module: z.string().trim().max(64).optional(),
  rule_name: z.string().trim().max(160).optional(),
  department_rule: csvTextSchema,
  cost_centre_rule: csvTextSchema,
  // Amount range narrows the rule's ordering weight; the tab has no monetary
  // column, so `priority` is the only numeric range it can filter on.
  priority_min: z.coerce.number().int().min(0).max(9999).optional(),
  priority_max: z.coerce.number().int().min(0).max(9999).optional(),
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

const postingRuleIdentifierParamsSchema = z.object({
  postingRuleIdentifier: uuidOrFriendlyIdentifierSchema,
});

const postingRuleActionParamsSchema = z.object({
  postingRuleIdentifier: uuidOrFriendlyIdentifierSchema,
  action: z.enum(POSTING_RULE_ACTIONS),
});

const accountRuleSchema = z.string().trim().min(1).max(120);

const postingRuleBaseSchema = z.object({
  rule_code: z
    .string()
    .trim()
    .min(1)
    .max(32)
    .regex(/^[A-Za-z0-9][A-Za-z0-9._-]*$/, {
      message: 'errors.accounts.posting_rule.invalid_code',
    }),
  rule_name: z.string().trim().min(1).max(160),
  source_module: z.string().trim().min(1).max(64),
  event_type: PostingRuleEventTypeEnum,
  debit_account_rule: accountRuleSchema,
  credit_account_rule: accountRuleSchema,
  tax_rule: z.string().trim().max(120).nullable().optional(),
  department_rule: z.string().trim().max(120).nullable().optional(),
  cost_centre_rule: z.string().trim().max(120).nullable().optional(),
  priority: z.coerce.number().int().min(0).max(9999).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  effective_from: optionalIsoDateSchema,
  effective_to: optionalIsoDateSchema,
  notes: z.string().trim().max(500).nullable().optional(),
});

/** The effective window must not run backwards. */
const withDateOrdering = (schema) =>
  schema.superRefine((value, ctx) => {
    const from = value?.effective_from ? Date.parse(value.effective_from) : null;
    const to = value?.effective_to ? Date.parse(value.effective_to) : null;
    if (from !== null && to !== null && to < from) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['effective_to'],
        message: 'errors.accounts.posting_rule.effective_to_before_from',
      });
    }
  });

/** The debit and credit sides of one rule must not target the same account. */
const withDistinctSides = (schema) =>
  schema.superRefine((value, ctx) => {
    const debit = String(value?.debit_account_rule ?? '').trim().toUpperCase();
    const credit = String(value?.credit_account_rule ?? '').trim().toUpperCase();
    if (debit && credit && debit === credit) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['credit_account_rule'],
        message: 'errors.accounts.posting_rule.same_debit_and_credit',
      });
    }
  });

const createPostingRuleSchema = withDistinctSides(
  withDateOrdering(postingRuleBaseSchema)
);

const updatePostingRuleSchema = withDistinctSides(
  withDateOrdering(
    postingRuleBaseSchema.partial().extend({
      version: z.coerce.number().int().min(1).optional(),
    })
  )
);

const postingRuleActionSchema = z.object({
  reason: z.string().trim().min(1).max(500).optional(),
  version: z.coerce.number().int().min(1).optional(),
});

module.exports = {
  POSTING_RULE_STATUSES,
  POSTING_RULE_TEST_STATUSES,
  POSTING_RULE_ACTIONS,
  POSTING_RULE_EVENT_TYPES,
  PostingRuleStatusEnum,
  PostingRuleEventTypeEnum,
  postingRulesQuerySchema,
  postingRuleIdentifierParamsSchema,
  postingRuleActionParamsSchema,
  createPostingRuleSchema,
  updatePostingRuleSchema,
  postingRuleActionSchema,
};
