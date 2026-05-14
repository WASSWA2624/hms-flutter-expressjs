/**
 * Drug batch module validation schemas
 *
 * @module modules/drug-batch/schemas
 * @description Zod validation schemas for drug batch endpoints.
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
 * Create drug batch body validation
 * Used for POST /drug-batches endpoint
 */
const createDrugBatchSchema = z.object({
  drug_id: uuidSchema,
  batch_number: z.string().trim().min(1).max(80),
  expiry_date: z.string().datetime().optional().nullable(),
  quantity: z.number().int().min(0).optional()
});

/**
 * Update drug batch body validation
 * Used for PUT /drug-batches/:id endpoint
 * All fields optional for partial updates
 */
const updateDrugBatchSchema = z.object({
  batch_number: z.string().trim().min(1).max(80).optional(),
  expiry_date: z.string().datetime().optional().nullable(),
  quantity: z.number().int().min(0).optional()
});

// ==================== URL Params ====================

/**
 * Drug batch ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const drugBatchIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List drug batches query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with drug batch-specific filters
 */
const listDrugBatchesQuerySchema = listQuerySchema.extend({
  drug_id: uuidSchema.optional(),
  batch_number: z.string().trim().optional(),
  expired: z.string().transform(val => val === 'true').optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createDrugBatchSchema,
  updateDrugBatchSchema,
  drugBatchIdParamsSchema,
  listDrugBatchesQuerySchema
};
