/**
 * Encounter module validation schemas
 *
 * @module modules/encounter/schemas
 * @description Zod validation schemas for encounter endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create encounter body validation
 * Used for POST /encounters endpoint
 */
const createEncounterSchema = z.object({
  tenant_id: uuidSchema,
  facility_id: uuidSchema.optional().nullable(),
  patient_id: uuidSchema,
  provider_user_id: uuidSchema.optional().nullable(),
  encounter_type: z.enum(['OPD', 'IPD', 'ICU', 'THEATRE', 'EMERGENCY', 'TELEMEDICINE']),
  status: z.enum(['OPEN', 'CLOSED', 'CANCELLED']).optional().default('OPEN'),
  started_at: isoDateSchema.optional(),
  ended_at: isoDateSchema.optional().nullable()
});

/**
 * Update encounter body validation
 * Used for PUT /encounters/:id endpoint
 * All fields optional for partial updates
 */
const updateEncounterSchema = z.object({
  facility_id: uuidSchema.optional().nullable(),
  provider_user_id: uuidSchema.optional().nullable(),
  encounter_type: z.enum(['OPD', 'IPD', 'ICU', 'THEATRE', 'EMERGENCY', 'TELEMEDICINE']).optional(),
  status: z.enum(['OPEN', 'CLOSED', 'CANCELLED']).optional(),
  started_at: isoDateSchema.optional(),
  ended_at: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * Encounter ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const encounterIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List encounters query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with encounter-specific filters
 */
const listEncountersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  patient_id: uuidSchema.optional(),
  provider_user_id: uuidSchema.optional(),
  encounter_type: z.enum(['OPD', 'IPD', 'ICU', 'THEATRE', 'EMERGENCY', 'TELEMEDICINE']).optional(),
  status: z.enum(['OPEN', 'CLOSED', 'CANCELLED']).optional()
});

module.exports = {
  createEncounterSchema,
  updateEncounterSchema,
  encounterIdParamsSchema,
  listEncountersQuerySchema
};
