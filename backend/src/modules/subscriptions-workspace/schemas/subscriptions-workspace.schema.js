const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const subscriptionsPanelSchema = z.enum([
  'overview',
  'catalog',
  'operations',
  'billing',
  'governance',
]);

const subscriptionsResourceSchema = z.enum([
  'subscription-plans',
  'modules',
  'subscriptions',
  'module-subscriptions',
  'subscription-invoices',
  'licenses',
]);

const subscriptionsDatePresetSchema = z.enum([
  'today',
  'last_30_days',
  'next_30_days',
  'next_renewal',
  'custom',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: subscriptionsPanelSchema.optional(),
  resource: subscriptionsResourceSchema.optional(),
  id: uuidOrFriendlyIdentifierSchema.optional(),
  action: z.string().trim().max(80).optional(),
  queue: z.string().trim().max(80).optional(),
  search: z.string().trim().max(160).optional(),
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.string().trim().max(80).optional(),
  tierCode: z.string().trim().max(80).optional(),
  tier_code: z.string().trim().max(80).optional(),
  billingCycle: z.string().trim().max(80).optional(),
  billing_cycle: z.string().trim().max(80).optional(),
  planId: uuidOrFriendlyIdentifierSchema.optional(),
  plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  moduleId: uuidOrFriendlyIdentifierSchema.optional(),
  module_id: uuidOrFriendlyIdentifierSchema.optional(),
  fitStatus: z.string().trim().max(80).optional(),
  fit_status: z.string().trim().max(80).optional(),
  changeStatus: z.string().trim().max(80).optional(),
  change_status: z.string().trim().max(80).optional(),
  invoiceStatus: z.string().trim().max(80).optional(),
  invoice_status: z.string().trim().max(80).optional(),
  licenseType: z.string().trim().max(80).optional(),
  license_type: z.string().trim().max(80).optional(),
  isAddOn: z.enum(['true', 'false']).optional(),
  is_add_on: z.enum(['true', 'false']).optional(),
  eligibilityState: z.string().trim().max(80).optional(),
  eligibility_state: z.string().trim().max(80).optional(),
  datePreset: subscriptionsDatePresetSchema.optional(),
  date_preset: subscriptionsDatePresetSchema.optional(),
  from: z.string().trim().optional(),
  to: z.string().trim().optional(),
});

const referenceDataQuerySchema = z.object({
  tenantId: uuidOrFriendlyIdentifierSchema.optional(),
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
});

const resolveLegacyParamsSchema = z.object({
  resource: subscriptionsResourceSchema,
  id: uuidOrFriendlyIdentifierSchema,
});

module.exports = {
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  subscriptionsPanelSchema,
  subscriptionsResourceSchema,
  workspaceQuerySchema,
};
