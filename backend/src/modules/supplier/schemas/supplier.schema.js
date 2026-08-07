/**
 * Supplier module validation schemas
 *
 * @module modules/supplier/schemas
 * @description Zod validation schemas for supplier endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const optionalBooleanSchema = z.preprocess((value) => {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
  }
  return value;
}, z.boolean().optional());

// ==================== Body Schemas ====================

/**
 * Create supplier body validation
 * Used for POST /suppliers endpoint
 */
const createSupplierSchema = z.object({
  tenant_id: uuidSchema,
  name: z.string().trim().min(1).max(255),
  contact_email: z.string().trim().email().max(255).optional().nullable(),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  location: z.string().trim().max(500).optional().nullable(),
  confirm_similar: optionalBooleanSchema,
});

/**
 * Update supplier body validation
 * Used for PUT /suppliers/:id endpoint
 * All fields optional for partial updates
 */
const updateSupplierSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  contact_email: z.string().trim().email().max(255).optional().nullable(),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  location: z.string().trim().max(500).optional().nullable(),
  confirm_similar: optionalBooleanSchema,
});

/**
 * Similarity preview body validation
 * Used for POST /suppliers/similarity-check
 */
const checkSupplierSimilaritySchema = z.object({
  tenant_id: uuidSchema.optional(),
  name: z.string().trim().min(1).max(255),
  contact_email: z.string().trim().email().max(255).optional().nullable(),
  phone: z.string().trim().min(1).max(40).optional().nullable(),
  location: z.string().trim().max(500).optional().nullable(),
  exclude_supplier_id: uuidSchema.optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Supplier ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const supplierIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List suppliers query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with supplier-specific filters
 */
const listSuppliersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  name: z.string().trim().optional(),
  contact_email: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createSupplierSchema,
  updateSupplierSchema,
  checkSupplierSimilaritySchema,
  supplierIdParamsSchema,
  listSuppliersQuerySchema
};
