/**
 * Ambulance module validation schemas
 *
 * @module modules/ambulance/schemas
 * @description Zod validation schemas for ambulance endpoints.
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
 * Create ambulance body validation
 * Used for POST /ambulances endpoint
 */
const createAmbulanceSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  identifier: z.string().trim().min(1).max(120),
  status: z.enum(['AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE'])
});

/**
 * Update ambulance body validation
 * Used for PUT /ambulances/:id endpoint
 * All fields optional for partial updates
 */
const updateAmbulanceSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  identifier: z.string().trim().min(1).max(120).optional(),
  status: z.enum(['AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE']).optional()
});

// ==================== URL Params ====================

/**
 * Ambulance ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const ambulanceIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List ambulances query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with ambulance-specific filters
 */
const listAmbulancesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createAmbulanceSchema,
  updateAmbulanceSchema,
  ambulanceIdParamsSchema,
  listAmbulancesQuerySchema
};
