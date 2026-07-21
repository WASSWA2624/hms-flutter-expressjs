/**
 * Coverage Plan (scheme) module validation schemas
 *
 * @module modules/coverage-plan/schemas
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema} = require('@lib/validation/zod');

const createCoveragePlanSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  insurance_company_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().min(1).max(64).optional().nullable(),
  provider_name: z.string().trim().min(1).max(255).optional().nullable(),
  coverage_percentage: z.number().int().min(0).max(100).optional().nullable(),
  status: z.enum(['ACTIVE', 'RETIRED']).optional().default('ACTIVE'),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable(),
  default_copay_type: z.enum(['NONE', 'FIXED', 'PERCENT']).optional().default('NONE'),
  default_copay_value: z.number().min(0).finite().optional().nullable()});

const updateCoveragePlanSchema = z.object({
  insurance_company_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  code: z.string().trim().min(1).max(64).optional().nullable(),
  provider_name: z.string().trim().min(1).max(255).optional().nullable(),
  coverage_percentage: z.number().int().min(0).max(100).optional().nullable(),
  status: z.enum(['ACTIVE', 'RETIRED']).optional(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable(),
  default_copay_type: z.enum(['NONE', 'FIXED', 'PERCENT']).optional(),
  default_copay_value: z.number().min(0).finite().optional().nullable()});

const coveragePlanIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

const listCoveragePlansQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  insurance_company_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  provider_name: z.string().trim().optional(),
  status: z.enum(['ACTIVE', 'RETIRED']).optional(),
  search: z.string().trim().optional()});

module.exports = {
  createCoveragePlanSchema,
  updateCoveragePlanSchema,
  coveragePlanIdParamsSchema,
  listCoveragePlansQuerySchema};
