/**
 * Asset service log module validation schemas
 *
 * @module modules/asset-service-log/schemas
 * @description Zod validation schemas for asset service log endpoints.
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
 * Create asset service log body validation
 * Used for POST /asset-service-logs endpoint
 */
const createAssetServiceLogSchema = z.object({
  asset_id: uuidOrFriendlyIdentifierSchema,
  serviced_at: z.string().datetime().optional(),
  notes: z.string().trim().optional().nullable()
});

/**
 * Update asset service log body validation
 * Used for PUT /asset-service-logs/:id endpoint
 * All fields optional for partial updates
 */
const updateAssetServiceLogSchema = z.object({
  serviced_at: z.string().datetime().optional(),
  notes: z.string().trim().optional().nullable()
});

// ==================== URL Params ====================

/**
 * Asset service log ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const assetServiceLogIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List asset service logs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with asset-service-log-specific filters
 */
const listAssetServiceLogsQuerySchema = listQuerySchema.extend({
  asset_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAssetServiceLogSchema,
  updateAssetServiceLogSchema,
  assetServiceLogIdParamsSchema,
  listAssetServiceLogsQuerySchema
};
