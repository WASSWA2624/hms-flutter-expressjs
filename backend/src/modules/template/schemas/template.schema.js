/**
 * Template module validation schemas
 *
 * @module modules/template/schemas
 * @description Zod validation schemas for template endpoints.
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
 * Create template body validation
 * Used for POST /templates endpoint
 */
const createTemplateSchema = z.object({
  tenant_id: uuidSchema,
  name: z.string().trim().min(1).max(120),
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']),
  body: z.string().trim().min(1)
});

/**
 * Update template body validation
 * Used for PUT /templates/:id endpoint
 * All fields optional for partial updates
 */
const updateTemplateSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']).optional(),
  body: z.string().trim().min(1).optional()
});

// ==================== URL Params ====================

/**
 * Template ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const templateIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List templates query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with template-specific filters
 */
const listTemplatesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  name: z.string().trim().optional(),
  channel: z.enum(['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createTemplateSchema,
  updateTemplateSchema,
  templateIdParamsSchema,
  listTemplatesQuerySchema
};
