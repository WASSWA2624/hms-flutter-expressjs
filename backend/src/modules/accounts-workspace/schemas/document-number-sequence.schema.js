/**
 * Document Numbering schemas
 *
 * @module modules/accounts-workspace/schemas
 * @description Zod contracts for `Accounts & Finance → Setup & Controls →
 * Document Numbering`. Public identifiers only; raw database IDs never appear
 * in requests or responses.
 */

const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const DOCUMENT_SEQUENCE_STATUSES = ['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'];
const DOCUMENT_SEQUENCE_ACTIONS = [
  'activate',
  'deactivate',
  'archive',
  'restore',
];
const DOCUMENT_SEQUENCE_TYPES = [
  'INVOICE',
  'ACCOUNTS_INVOICE',
  'RECEIPT',
  'PAYMENT',
  'REFUND',
  'CREDIT_NOTE',
  'DEBIT_NOTE',
  'PURCHASE_ORDER',
  'GOODS_RECEIPT',
  'CLAIM',
];
const DOCUMENT_SEQUENCE_RESET_FREQUENCIES = [
  'NEVER',
  'DAILY',
  'MONTHLY',
  'QUARTERLY',
  'YEARLY',
];
const DOCUMENT_SEQUENCE_GAP_POLICIES = [
  'ALLOW_GAPS',
  'NO_GAPS',
  'RESERVE_AND_VOID',
];

const DocumentSequenceStatusEnum = z.enum(DOCUMENT_SEQUENCE_STATUSES);

const isoDateSchema = z
  .string()
  .trim()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), {
    message: 'errors.validation.invalid_date',
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

/**
 * A literal date pattern such as `yyyyMM`, not a calendar date. Only the
 * characters the formatter understands are accepted, so a pattern can never
 * smuggle arbitrary text into an issued reference.
 */
const datePatternSchema = z
  .string()
  .trim()
  .max(32)
  .regex(/^[yYmMdDqQwW'\-/.]*$/, {
    message: 'errors.accounts.document_sequence.invalid_date_pattern',
  });

/** Prefix and suffix become part of a public reference: keep them printable. */
const affixSchema = z
  .string()
  .trim()
  .max(16)
  .regex(/^[A-Za-z0-9\-/]*$/, {
    message: 'errors.accounts.document_sequence.invalid_affix',
  });

const documentSequencesQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  status: csvEnumSchema(DOCUMENT_SEQUENCE_STATUSES),
  document_type: csvEnumSchema(DOCUMENT_SEQUENCE_TYPES),
  module: z.string().trim().max(32).optional(),
  sequence_code: z.string().trim().max(32).optional(),
  prefix: z.string().trim().max(16).optional(),
  reset_frequency: csvEnumSchema(DOCUMENT_SEQUENCE_RESET_FREQUENCIES),
  gap_policy: csvEnumSchema(DOCUMENT_SEQUENCE_GAP_POLICIES),
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

const documentSequenceIdentifierParamsSchema = z.object({
  documentSequenceIdentifier: uuidOrFriendlyIdentifierSchema,
});

const documentSequenceActionParamsSchema = z.object({
  documentSequenceIdentifier: uuidOrFriendlyIdentifierSchema,
  action: z.enum(DOCUMENT_SEQUENCE_ACTIONS),
});

const documentSequenceBaseSchema = z.object({
  sequence_code: z
    .string()
    .trim()
    .min(1)
    .max(32)
    .regex(/^[A-Za-z0-9\-_]+$/, {
      message: 'errors.accounts.document_sequence.invalid_code',
    }),
  document_type: z.enum(DOCUMENT_SEQUENCE_TYPES),
  module: z.string().trim().min(1).max(32),
  facility_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  prefix: affixSchema.min(1),
  suffix: affixSchema.nullable().optional(),
  date_pattern: datePatternSchema.nullable().optional(),
  minimum_length: z.coerce.number().int().min(1).max(20),
  reset_frequency: z.enum(DOCUMENT_SEQUENCE_RESET_FREQUENCIES),
  gap_policy: z.enum(DOCUMENT_SEQUENCE_GAP_POLICIES).optional(),
  notes: z.string().trim().max(500).nullable().optional(),
});

/**
 * A prefix plus a padded number plus a suffix must still fit the reference
 * column, and the padded number alone must leave room for the affixes.
 */
const MAX_REFERENCE_LENGTH = 32;

const withReferenceBudget = (schema) =>
  schema.superRefine((value, ctx) => {
    const prefix = value?.prefix ?? '';
    const suffix = value?.suffix ?? '';
    const datePattern = value?.date_pattern ?? '';
    const minimumLength = Number(value?.minimum_length ?? 0);
    if (!Number.isFinite(minimumLength) || minimumLength <= 0) return;

    const width =
      prefix.length + suffix.length + datePattern.length + minimumLength;
    if (width > MAX_REFERENCE_LENGTH) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['minimum_length'],
        message: 'errors.accounts.document_sequence.reference_too_long',
      });
    }
  });

const createDocumentSequenceSchema = withReferenceBudget(
  documentSequenceBaseSchema
);

const updateDocumentSequenceSchema = withReferenceBudget(
  documentSequenceBaseSchema.partial().extend({
    version: z.coerce.number().int().min(1).optional(),
  })
);

const documentSequenceActionSchema = z.object({
  reason: z.string().trim().min(1).max(500).optional(),
  version: z.coerce.number().int().min(1).optional(),
});

module.exports = {
  DOCUMENT_SEQUENCE_STATUSES,
  DOCUMENT_SEQUENCE_ACTIONS,
  DOCUMENT_SEQUENCE_TYPES,
  DOCUMENT_SEQUENCE_RESET_FREQUENCIES,
  DOCUMENT_SEQUENCE_GAP_POLICIES,
  MAX_REFERENCE_LENGTH,
  DocumentSequenceStatusEnum,
  documentSequencesQuerySchema,
  documentSequenceIdentifierParamsSchema,
  documentSequenceActionParamsSchema,
  createDocumentSequenceSchema,
  updateDocumentSequenceSchema,
  documentSequenceActionSchema,
};
