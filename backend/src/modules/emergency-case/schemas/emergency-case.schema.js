/**
 * Emergency case module validation schemas
 *
 * @module modules/emergency-case/schemas
 * @description Zod validation schemas for emergency case endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const EMERGENCY_CASE_STATUS_VALUES = [
  'OPEN',
  'CLOSED',
  'CANCELLED',
  // Backward compatibility aliases
  'PENDING',
  'IN_PROGRESS',
  'COMPLETED',
];

// ==================== Body Schemas ====================

/**
 * Create emergency case body validation
 * Used for POST /emergency-cases endpoint
 */
const createEmergencyCaseSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema,
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
  status: z.enum(EMERGENCY_CASE_STATUS_VALUES)
});

/**
 * Update emergency case body validation
 * Used for PUT /emergency-cases/:id endpoint
 * All fields optional for partial updates
 */
const updateEmergencyCaseSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
  status: z.enum(EMERGENCY_CASE_STATUS_VALUES).optional()
});

// ==================== URL Params ====================

/**
 * Emergency case ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const emergencyCaseIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List emergency cases query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with emergency case-specific filters
 */
const listEmergencyCasesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
  status: z.enum(EMERGENCY_CASE_STATUS_VALUES).optional(),
  search: z.string().trim().max(255).optional()
});

module.exports = {
  createEmergencyCaseSchema,
  updateEmergencyCaseSchema,
  emergencyCaseIdParamsSchema,
  listEmergencyCasesQuerySchema
};
