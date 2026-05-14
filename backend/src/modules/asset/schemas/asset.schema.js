/**
 * Asset module validation schemas
 *
 * @module modules/asset/schemas
 * @description Zod validation schemas for asset endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Maintenance status enum (matches Prisma schema)
 * Enum values: OPEN, IN_PROGRESS, COMPLETED, CANCELLED
 */
const maintenanceStatusEnum = z.enum(['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']);

// ==================== Body Schemas ====================

/**
 * Create asset body validation
 * Used for POST /assets endpoint
 */
const createAssetSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  asset_tag: z.string().trim().max(80).optional().nullable(),
  status: maintenanceStatusEnum
});

/**
 * Update asset body validation
 * Used for PUT /assets/:id endpoint
 * All fields optional for partial updates
 */
const updateAssetSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(255).optional(),
  asset_tag: z.string().trim().max(80).optional().nullable(),
  status: maintenanceStatusEnum.optional()
});

// ==================== URL Params ====================

/**
 * Asset ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const assetIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List assets query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with asset-specific filters
 */
const listAssetsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  asset_tag: z.string().trim().optional(),
  status: maintenanceStatusEnum.optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAssetSchema,
  updateAssetSchema,
  assetIdParamsSchema,
  listAssetsQuerySchema,
  maintenanceStatusEnum
};
