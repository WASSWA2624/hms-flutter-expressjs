/**
 * Coverage Plan module validation schemas
 *
 * @module modules/coverage-plan/schemas
 * @description Zod validation schemas for coverage plan endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create coverage plan body validation
 * Used for POST /coverage-plans endpoint
 */
const createCoveragePlanSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  provider_name: z.string().trim().min(1).max(255).optional().nullable(),
  coverage_percentage: z.number().int().min(0).max(100).optional().nullable()
});

/**
 * Update coverage plan body validation
 * Used for PUT /coverage-plans/:id endpoint
 * All fields optional for partial updates
 */
const updateCoveragePlanSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  provider_name: z.string().trim().min(1).max(255).optional().nullable(),
  coverage_percentage: z.number().int().min(0).max(100).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Coverage Plan ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const coveragePlanIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List coverage plans query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with coverage plan-specific filters
 */
const listCoveragePlansQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  provider_name: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createCoveragePlanSchema,
  updateCoveragePlanSchema,
  coveragePlanIdParamsSchema,
  listCoveragePlansQuerySchema
};
