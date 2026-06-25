/**
 * Claims workspace validation schemas
 *
 * @module modules/claims-workspace/schemas
 * @description Zod query validation for the insurance and claims workspace.
 */

const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');

const workspaceQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(120).optional(),
});

const workItemsQuerySchema = listQuerySchema.extend({
  queue: z.string().trim().max(40).optional(),
  kind: z.enum(['AUTHORIZATION', 'CLAIM', 'PRE_AUTH']).optional(),
  status: z
    .enum(['PENDING', 'APPROVED', 'DENIED', 'EXPIRED', 'SUBMITTED', 'REJECTED', 'PAID', 'CANCELLED'])
    .optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().max(120).optional(),
});

const lookupsQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
});

const authorizationContextQuerySchema = listQuerySchema.extend({
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  admission_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
});

module.exports = {
  workspaceQuerySchema,
  workItemsQuerySchema,
  lookupsQuerySchema,
  authorizationContextQuerySchema,
};
