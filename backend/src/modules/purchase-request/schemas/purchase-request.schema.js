/**
 * Purchase request module validation schemas
 *
 * @module modules/purchase-request/schemas
 * @description Zod validation schemas for purchase request endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create purchase request body validation
 * Used for POST /purchase-requests endpoint
 */
const createPurchaseRequestSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  requested_by_user_id: uuidSchema.optional().nullable(),
  status: z.string().trim().min(1).max(60),
  requested_at: z.string().datetime().optional()
});

/**
 * Update purchase request body validation
 * Used for PUT /purchase-requests/:id endpoint
 * All fields optional for partial updates
 */
const updatePurchaseRequestSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  requested_by_user_id: uuidSchema.optional().nullable(),
  status: z.string().trim().min(1).max(60).optional(),
  requested_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Purchase request ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const purchaseRequestIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List purchase requests query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with purchase request-specific filters
 */
const listPurchaseRequestsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  requested_by_user_id: uuidSchema.optional(),
  status: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPurchaseRequestSchema,
  updatePurchaseRequestSchema,
  purchaseRequestIdParamsSchema,
  listPurchaseRequestsQuerySchema
};
