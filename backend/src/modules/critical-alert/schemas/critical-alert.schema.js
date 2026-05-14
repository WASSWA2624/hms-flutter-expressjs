/**
 * Critical Alert module validation schemas
 *
 * @module modules/critical-alert/schemas
 * @description Zod validation schemas for critical-alert endpoints.
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
 * Create critical alert body validation
 * Used for POST /critical-alerts endpoint
 */
const createCriticalAlertSchema = z.object({
  icu_stay_id: uuidOrFriendlyIdentifierSchema,
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
  message: z.string().trim().min(1).max(2000)
});

/**
 * Update critical alert body validation
 * Used for PUT /critical-alerts/:id endpoint
 * All fields optional for partial updates
 */
const updateCriticalAlertSchema = z.object({
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
  message: z.string().trim().min(1).max(2000).optional()
});

// ==================== URL Params ====================

/**
 * Critical Alert ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const criticalAlertIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List critical alerts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with critical-alert-specific filters
 */
const listCriticalAlertsQuerySchema = listQuerySchema.extend({
  icu_stay_id: uuidOrFriendlyIdentifierSchema.optional(),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createCriticalAlertSchema,
  updateCriticalAlertSchema,
  criticalAlertIdParamsSchema,
  listCriticalAlertsQuerySchema
};
