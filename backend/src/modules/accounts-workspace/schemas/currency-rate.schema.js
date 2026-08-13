/**
 * Currencies & Exchange Rates schemas
 *
 * @module modules/accounts-workspace/schemas
 * @description Zod contracts for `Accounts & Finance → Setup & Controls →
 * Currencies & Exchange Rates`. Public identifiers only; raw database IDs never
 * appear in requests or responses.
 */

const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const CURRENCY_RATE_STATUSES = ['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'];
const CURRENCY_RATE_ACTIONS = ['activate', 'deactivate', 'archive', 'restore'];
const CURRENCY_RATE_TYPES = [
  'SPOT',
  'DAILY',
  'MONTHLY',
  'BUDGET',
  'CONTRACT',
];

const CURRENCY_RATE_MIN = 0.00000001;
const CURRENCY_RATE_MAX = 100000000;

const CurrencyRateStatusEnum = z.enum(CURRENCY_RATE_STATUSES);
const CurrencyRateTypeEnum = z.enum(CURRENCY_RATE_TYPES);

const isoDateSchema = z
  .string()
  .trim()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), {
    message: 'errors.validation.invalid_date',
  });

const currencyCodeSchema = z
  .string()
  .trim()
  .length(3)
  .transform((value) => value.toUpperCase())
  .refine((value) => /^[A-Z]{3}$/.test(value), {
    message: 'errors.accounts.currency_rate.invalid_code',
  });

const rateSchema = z.coerce
  .number()
  .positive()
  .min(CURRENCY_RATE_MIN)
  .max(CURRENCY_RATE_MAX);

const optionalRateSchema = rateSchema.nullable().optional();

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

const currencyRatesQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  status: csvEnumSchema(CURRENCY_RATE_STATUSES),
  currency_code: z
    .string()
    .trim()
    .max(3)
    .optional()
    .transform((value) => (value ? value.toUpperCase() : undefined)),
  rate_type: csvEnumSchema(CURRENCY_RATE_TYPES),
  base_currency: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => (value === undefined ? undefined : value === 'true')),
  source: z.string().trim().max(120).optional(),
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

const currencyRateIdentifierParamsSchema = z.object({
  currencyRateIdentifier: uuidOrFriendlyIdentifierSchema,
});

const currencyRateActionParamsSchema = z.object({
  currencyRateIdentifier: uuidOrFriendlyIdentifierSchema,
  action: z.enum(CURRENCY_RATE_ACTIONS),
});

const currencyRateBaseSchema = z.object({
  currency_code: currencyCodeSchema,
  currency_name: z.string().trim().min(1).max(120),
  symbol: z.string().trim().min(1).max(8),
  decimal_places: z.coerce.number().int().min(0).max(6),
  is_base_currency: z.coerce.boolean().optional(),
  rate_type: CurrencyRateTypeEnum.optional(),
  exchange_rate: rateSchema,
  effective_date: isoDateSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  source: z.string().trim().max(120).nullable().optional(),
  buy_rate: optionalRateSchema,
  sell_rate: optionalRateSchema,
  notes: z.string().trim().max(500).nullable().optional(),
});

/**
 * A base currency is fixed at parity, and a buy rate may never exceed the
 * matching sell rate.
 */
const withRateConsistency = (schema) =>
  schema.superRefine((value, ctx) => {
    const buy = value?.buy_rate;
    const sell = value?.sell_rate;
    if (
      typeof buy === 'number' &&
      typeof sell === 'number' &&
      buy > sell
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['buy_rate'],
        message: 'errors.accounts.currency_rate.buy_above_sell',
      });
    }

    if (value?.is_base_currency === true && value?.exchange_rate !== undefined) {
      if (Number(value.exchange_rate) !== 1) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['exchange_rate'],
          message: 'errors.accounts.currency_rate.base_rate_must_be_one',
        });
      }
    }
  });

const createCurrencyRateSchema = withRateConsistency(currencyRateBaseSchema);

const updateCurrencyRateSchema = withRateConsistency(
  currencyRateBaseSchema.partial().extend({
    version: z.coerce.number().int().min(1).optional(),
  })
);

const currencyRateActionSchema = z.object({
  reason: z.string().trim().min(1).max(500).optional(),
  version: z.coerce.number().int().min(1).optional(),
});

module.exports = {
  CURRENCY_RATE_STATUSES,
  CURRENCY_RATE_ACTIONS,
  CURRENCY_RATE_TYPES,
  CURRENCY_RATE_MIN,
  CURRENCY_RATE_MAX,
  CurrencyRateStatusEnum,
  CurrencyRateTypeEnum,
  currencyRatesQuerySchema,
  currencyRateIdentifierParamsSchema,
  currencyRateActionParamsSchema,
  createCurrencyRateSchema,
  updateCurrencyRateSchema,
  currencyRateActionSchema,
};
