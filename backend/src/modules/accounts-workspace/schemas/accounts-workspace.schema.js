const { z } = require('zod');
const {
  listQuerySchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const workspaceQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const patientLedgersQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  clearance: z.enum(['CLEARED', 'PARTIAL', 'OUTSTANDING']).optional(),
});

const patientLedgerParamsSchema = z.object({
  patientIdentifier: uuidOrFriendlyIdentifierSchema,
});

const patientLedgerQuerySchema = listQuerySchema.extend({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

const workItemsQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  section: z.string().trim().optional(),
  source: z.string().trim().optional(),
  status: z.string().trim().optional(),
  // Section-specific filters forwarded to the owning resource service.
  fiscal_year: z.string().trim().max(32).optional(),
  module: z.string().trim().max(32).optional(),
  period_name: z.string().trim().max(120).optional(),
  department_code: z.string().trim().max(32).optional(),
  department_name: z.string().trim().max(255).optional(),
  cost_centre_code: z.string().trim().max(512).optional(),
  cost_centre_name: z.string().trim().max(160).optional(),
  default_revenue_account_id: uuidOrFriendlyIdentifierSchema.optional(),
  default_expense_account_id: uuidOrFriendlyIdentifierSchema.optional(),
  owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  budget_owner_id: uuidOrFriendlyIdentifierSchema.optional(),
  from: z.string().trim().optional(),
  to: z.string().trim().optional(),
});

const glAccountsQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
  account_type: z.string().trim().optional(),
  period: z.string().trim().optional(),
  account_id: uuidOrFriendlyIdentifierSchema.optional(),
  has_activity: z
    .enum(['true', 'false', '1', '0'])
    .optional()
    .transform((value) => {
      if (value == null) return undefined;
      return value === 'true' || value === '1';
    }),
});

const accountIdentifierParamsSchema = z.object({
  accountIdentifier: uuidOrFriendlyIdentifierSchema,
});

const accountLedgerQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

module.exports = {
  workspaceQuerySchema,
  patientLedgersQuerySchema,
  patientLedgerParamsSchema,
  patientLedgerQuerySchema,
  workItemsQuerySchema,
  glAccountsQuerySchema,
  accountIdentifierParamsSchema,
  accountLedgerQuerySchema,
};
