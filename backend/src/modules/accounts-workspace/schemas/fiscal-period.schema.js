/**
 * Fiscal Years & Periods schemas
 *
 * @module modules/accounts-workspace/schemas
 * @description Zod contracts for `Accounts & Finance → Setup & Controls →
 * Fiscal Years & Periods`. Public identifiers only; raw database IDs never
 * appear in requests or responses.
 */

const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const FISCAL_PERIOD_STATUSES = ['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'];
const FISCAL_PERIOD_ACTIONS = ['activate', 'deactivate', 'archive', 'restore'];

const FiscalPeriodStatusEnum = z.enum(FISCAL_PERIOD_STATUSES);

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

const fiscalPeriodsQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  status: csvEnumSchema(FISCAL_PERIOD_STATUSES),
  fiscal_year: z.string().trim().max(32).optional(),
  module: z.string().trim().max(32).optional(),
  period_name: z.string().trim().max(120).optional(),
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

const fiscalPeriodIdentifierParamsSchema = z.object({
  fiscalPeriodIdentifier: uuidOrFriendlyIdentifierSchema,
});

const fiscalPeriodActionParamsSchema = z.object({
  fiscalPeriodIdentifier: uuidOrFriendlyIdentifierSchema,
  action: z.enum(FISCAL_PERIOD_ACTIONS),
});

const fiscalPeriodBaseSchema = z.object({
  fiscal_year: z.string().trim().min(1).max(32),
  period_no: z.coerce.number().int().min(1).max(366),
  period_name: z.string().trim().min(1).max(120),
  start_date: isoDateSchema,
  end_date: isoDateSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  module: z.string().trim().min(1).max(32).optional(),
  open_date: optionalIsoDateSchema,
  soft_close_date: optionalIsoDateSchema,
  close_date: optionalIsoDateSchema,
  lock_date: optionalIsoDateSchema,
  notes: z.string().trim().max(500).nullable().optional(),
});

/** Start/end and the close milestones must stay in chronological order. */
const withDateOrdering = (schema) =>
  schema.superRefine((value, ctx) => {
    const at = (field) => {
      const raw = value?.[field];
      return raw ? Date.parse(raw) : null;
    };

    const start = at('start_date');
    const end = at('end_date');
    if (start !== null && end !== null && end < start) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['end_date'],
        message: 'errors.accounts.fiscal_period.end_before_start',
      });
    }

    const milestones = [
      ['open_date', 'soft_close_date'],
      ['soft_close_date', 'close_date'],
      ['close_date', 'lock_date'],
    ];
    for (const [earlier, later] of milestones) {
      const a = at(earlier);
      const b = at(later);
      if (a !== null && b !== null && b < a) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: [later],
          message: 'errors.accounts.fiscal_period.milestone_out_of_order',
        });
      }
    }
  });

const createFiscalPeriodSchema = withDateOrdering(fiscalPeriodBaseSchema);

const updateFiscalPeriodSchema = withDateOrdering(
  fiscalPeriodBaseSchema.partial().extend({
    version: z.coerce.number().int().min(1).optional(),
  })
);

const fiscalPeriodActionSchema = z.object({
  reason: z.string().trim().min(1).max(500).optional(),
  version: z.coerce.number().int().min(1).optional(),
});

module.exports = {
  FISCAL_PERIOD_STATUSES,
  FISCAL_PERIOD_ACTIONS,
  FiscalPeriodStatusEnum,
  fiscalPeriodsQuerySchema,
  fiscalPeriodIdentifierParamsSchema,
  fiscalPeriodActionParamsSchema,
  createFiscalPeriodSchema,
  updateFiscalPeriodSchema,
  fiscalPeriodActionSchema,
};
