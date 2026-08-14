/**
 * Departments & Cost Centres schemas
 *
 * @module modules/accounts-workspace/schemas
 * @description Zod contracts for `Accounts & Finance → Setup & Controls →
 * Departments & Cost Centres`. The record itself stays owned by
 * `modules/department`; these contracts cover the finance projection
 * (cost centre, default posting accounts, ownership, effective window,
 * lifecycle). Public identifiers only; raw database IDs never appear in
 * requests or responses.
 */

const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const DEPARTMENT_STATUSES = ['DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED'];
const DEPARTMENT_ACTIONS = ['activate', 'deactivate', 'archive', 'restore'];

const DepartmentStatusEnum = z.enum(DEPARTMENT_STATUSES);

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

/** Comma-separated free-text multi-select (hierarchical department picker). */
const csvTextSchema = z
  .string()
  .trim()
  .optional()
  .transform((value) => {
    if (!value) return undefined;
    const parsed = value
      .split(',')
      .map((entry) => entry.trim())
      .filter(Boolean);
    return parsed.length ? parsed : undefined;
  });

const departmentsQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  status: csvEnumSchema(DEPARTMENT_STATUSES),
  department_code: z.string().trim().max(32).optional(),
  department_name: z.string().trim().max(255).optional(),
  cost_centre_code: csvTextSchema,
  cost_centre_name: z.string().trim().max(160).optional(),
  default_revenue_account_id: uuidOrFriendlyIdentifierSchema.optional(),
  default_expense_account_id: uuidOrFriendlyIdentifierSchema.optional(),
  // Owner / assigned user filter: manager or budget owner.
  owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  budget_owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

const departmentIdentifierParamsSchema = z.object({
  departmentIdentifier: uuidOrFriendlyIdentifierSchema,
});

const departmentActionParamsSchema = z.object({
  departmentIdentifier: uuidOrFriendlyIdentifierSchema,
  action: z.enum(DEPARTMENT_ACTIONS),
});

const departmentBaseSchema = z.object({
  department_code: z.string().trim().min(1).max(32),
  department_name: z.string().trim().min(1).max(255),
  cost_centre_code: z.string().trim().min(1).max(32),
  cost_centre_name: z.string().trim().min(1).max(160),
  parent_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  manager_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  default_revenue_account_id: uuidOrFriendlyIdentifierSchema
    .nullable()
    .optional(),
  default_expense_account_id: uuidOrFriendlyIdentifierSchema
    .nullable()
    .optional(),
  budget_owner_id: uuidOrFriendlyIdentifierSchema.nullable().optional(),
  effective_from: optionalIsoDateSchema,
  effective_to: optionalIsoDateSchema,
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
        message: 'errors.accounts.department.effective_to_before_from',
      });
    }
  });

const createDepartmentSchema = withDateOrdering(departmentBaseSchema);

const updateDepartmentSchema = withDateOrdering(
  departmentBaseSchema.partial().extend({
    version: z.coerce.number().int().min(1).optional(),
  })
);

const departmentActionSchema = z.object({
  reason: z.string().trim().min(1).max(500).optional(),
  version: z.coerce.number().int().min(1).optional(),
});

module.exports = {
  DEPARTMENT_STATUSES,
  DEPARTMENT_ACTIONS,
  DepartmentStatusEnum,
  departmentsQuerySchema,
  departmentIdentifierParamsSchema,
  departmentActionParamsSchema,
  createDepartmentSchema,
  updateDepartmentSchema,
  departmentActionSchema,
};
