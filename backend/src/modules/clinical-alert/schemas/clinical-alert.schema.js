/**
 * Clinical Alert module validation schemas
 *
 * @module modules/clinical-alert/schemas
 * @description Zod validation schemas for clinical alert endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const CLINICAL_ALERT_SEVERITY_VALUES = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const CLINICAL_ALERT_STATUS_VALUES = ['NEW', 'ACKNOWLEDGED', 'RESOLVED'];
const CLINICAL_ALERT_SOURCE_VALUES = ['MANUAL', 'AUTO_VITAL'];

// ==================== Body Schemas ====================

/**
 * Create clinical alert body validation
 * Used for POST /clinical-alerts endpoint
 */
const createClinicalAlertSchema = z.object({
  encounter_id: uuidSchema,
  severity: z.enum(CLINICAL_ALERT_SEVERITY_VALUES),
  message: z.string().trim().min(1),
  source: z.enum(CLINICAL_ALERT_SOURCE_VALUES).optional().default('MANUAL'),
  vital_sign_id: uuidSchema.optional().nullable()
});

/**
 * Update clinical alert body validation
 * Used for PUT /clinical-alerts/:id endpoint
 * All fields optional for partial updates
 */
const updateClinicalAlertSchema = z.object({
  encounter_id: uuidSchema.optional(),
  severity: z.enum(CLINICAL_ALERT_SEVERITY_VALUES).optional(),
  message: z.string().trim().min(1).optional(),
  status: z.enum(CLINICAL_ALERT_STATUS_VALUES).optional()
});

const acknowledgeClinicalAlertSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable()
});

const resolveClinicalAlertSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Clinical alert ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const clinicalAlertIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List clinical alerts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with clinical alert-specific filters
 */
const listClinicalAlertsQuerySchema = listQuerySchema.extend({
  encounter_id: uuidSchema.optional(),
  severity: z.enum(CLINICAL_ALERT_SEVERITY_VALUES).optional(),
  status: z.enum(CLINICAL_ALERT_STATUS_VALUES).optional(),
  source: z.enum(CLINICAL_ALERT_SOURCE_VALUES).optional(),
  vital_sign_id: uuidSchema.optional()
});

module.exports = {
  createClinicalAlertSchema,
  updateClinicalAlertSchema,
  acknowledgeClinicalAlertSchema,
  resolveClinicalAlertSchema,
  clinicalAlertIdParamsSchema,
  listClinicalAlertsQuerySchema,
  CLINICAL_ALERT_SEVERITY_VALUES,
  CLINICAL_ALERT_STATUS_VALUES,
  CLINICAL_ALERT_SOURCE_VALUES,
};
