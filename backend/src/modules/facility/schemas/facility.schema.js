/**
 * Facility module validation schemas
 *
 * @module modules/facility/schemas
 * @description Zod validation schemas for facility endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema 
} = require('@lib/validation/zod');

const extensionJsonSchema = z.record(z.string(), z.unknown()).optional().nullable();

// ==================== Enums ====================

/**
 * Facility type enum
 * Must match Prisma FacilityType enum
 */
const facilityTypeEnum = z.enum(['HOSPITAL', 'CLINIC', 'LAB', 'PHARMACY', 'OTHER']);

// ==================== Body Schemas ====================

/**
 * Create facility body validation
 * Used for POST /facilities endpoint
 */
const createFacilitySchema = z.object({
  tenant_id: uuidSchema,
  name: z.string().trim().min(1).max(255),
  facility_type: facilityTypeEnum,
  is_active: z.boolean().optional(),
  extension_json: extensionJsonSchema,
});

/**
 * Update facility body validation
 * Used for PUT /facilities/:id endpoint
 * All fields optional for partial updates
 */
const updateFacilitySchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  facility_type: facilityTypeEnum.optional(),
  is_active: z.boolean().optional(),
  extension_json: extensionJsonSchema,
});

// ==================== URL Params ====================

/**
 * Facility ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const facilityIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List facilities query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with facility-specific filters
 */
const listFacilitiesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_type: facilityTypeEnum.optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createFacilitySchema,
  updateFacilitySchema,
  facilityIdParamsSchema,
  listFacilitiesQuerySchema,
  facilityTypeEnum
};
