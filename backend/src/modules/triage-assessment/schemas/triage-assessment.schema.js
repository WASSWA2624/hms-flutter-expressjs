/**
 * Triage assessment module validation schemas
 *
 * @module modules/triage-assessment/schemas
 * @description Zod validation schemas for triage assessment endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const TRIAGE_LEVEL_VALUES = [
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  // Backward compatibility aliases
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT',
];

// ==================== Body Schemas ====================

/**
 * Create triage assessment body validation
 * Used for POST /triage-assessments endpoint
 */
const createTriageAssessmentSchema = z.object({
  emergency_case_id: uuidOrFriendlyIdentifierSchema,
  triage_level: z.enum(TRIAGE_LEVEL_VALUES),
  notes: z.string().max(5000).optional().nullable()
});

/**
 * Update triage assessment body validation
 * Used for PUT /triage-assessments/:id endpoint
 * All fields optional for partial updates
 */
const updateTriageAssessmentSchema = z.object({
  emergency_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  triage_level: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  notes: z.string().max(5000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Triage assessment ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const triageAssessmentIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List triage assessments query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with triage assessment-specific filters
 */
const listTriageAssessmentsQuerySchema = listQuerySchema.extend({
  emergency_case_id: uuidOrFriendlyIdentifierSchema.optional(),
  triage_level: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  search: z.string().trim().max(255).optional()
});

module.exports = {
  createTriageAssessmentSchema,
  updateTriageAssessmentSchema,
  triageAssessmentIdParamsSchema,
  listTriageAssessmentsQuerySchema
};
