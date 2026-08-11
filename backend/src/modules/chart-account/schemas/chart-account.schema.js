/**
 * Chart Account module validation schemas
 *
 * @module modules/chart-account/schemas
 * @description Zod validation schemas for chart account endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

const ChartAccountTypeEnum = z.enum([
  'ASSET',
  'LIABILITY',
  'EQUITY',
  'REVENUE',
  'EXPENSE'
]);

// ==================== Body Schemas ====================

/**
 * Create chart account body validation
 * Used for POST /chart-accounts endpoint
 */
const createChartAccountSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  code: z.string().trim().min(1).max(64),
  name: z.string().trim().min(1).max(255),
  account_type: ChartAccountTypeEnum,
  parent_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  currency: z.string().trim().min(1).max(10).toUpperCase().optional().default('UGX'),
  effective_from: z.string().datetime().optional().nullable(),
  is_active: z.boolean().optional().default(true),
  notes: z.string().trim().max(255).optional().nullable()
});

/**
 * Update chart account body validation
 * Used for PUT /chart-accounts/:id endpoint
 * All fields optional for partial updates (including is_active:false for deactivate)
 */
const updateChartAccountSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  code: z.string().trim().min(1).max(64).optional(),
  name: z.string().trim().min(1).max(255).optional(),
  account_type: ChartAccountTypeEnum.optional(),
  parent_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  currency: z.string().trim().min(1).max(10).toUpperCase().optional(),
  effective_from: z.string().datetime().optional().nullable(),
  is_active: z.boolean().optional(),
  notes: z.string().trim().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Chart Account ID URL parameter validation
 * Used for GET /:id and PUT /:id endpoints
 */
const chartAccountIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List chart accounts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with chart account-specific filters
 */
const listChartAccountsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  account_type: ChartAccountTypeEnum.optional(),
  parent_id: uuidOrFriendlyIdentifierSchema.optional(),
  currency: z.string().trim().min(1).max(10).toUpperCase().optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createChartAccountSchema,
  updateChartAccountSchema,
  chartAccountIdParamsSchema,
  listChartAccountsQuerySchema,
  ChartAccountTypeEnum
};
