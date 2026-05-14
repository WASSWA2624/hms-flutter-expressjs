const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const jsonObjectSchema = z.object({}).passthrough();

const createAbacPolicySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  description: z.string().trim().max(10000).optional().nullable(),
  resource_type: z.string().trim().min(1).max(120),
  action: z.string().trim().min(1).max(120),
  effect: z.enum(['ALLOW', 'DENY']),
  priority: z.coerce.number().int().min(0).max(100000).optional(),
  subject_conditions_json: jsonObjectSchema.optional().nullable(),
  object_conditions_json: jsonObjectSchema.optional().nullable(),
  environment_conditions_json: jsonObjectSchema.optional().nullable(),
  reason_template: z.string().trim().max(255).optional().nullable(),
  is_active: z.boolean().optional(),
});

const updateAbacPolicySchema = createAbacPolicySchema.partial();

const abacPolicyIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const listAbacPoliciesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  branch_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  resource_type: z.string().trim().optional(),
  action: z.string().trim().optional(),
  effect: z.enum(['ALLOW', 'DENY']).optional(),
  is_active: z.union([z.boolean(), z.enum(['true', 'false'])]).optional(),
});

module.exports = {
  abacPolicyIdParamsSchema,
  createAbacPolicySchema,
  listAbacPoliciesQuerySchema,
  updateAbacPolicySchema,
};
