/**
 * Template Variable module validation schemas
 *
 * @module modules/template-variable/schemas
 * @description Zod validation schemas for template-variable endpoints.
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
 * Create template variable body validation
 * Used for POST /template-variables endpoint
 */
const createTemplateVariableSchema = z.object({
  template_id: uuidSchema,
  key: z.string().trim().min(1).max(120),
  description: z.string().trim().max(255).optional().nullable()
});

/**
 * Update template variable body validation
 * Used for PUT /template-variables/:id endpoint
 * All fields optional for partial updates
 */
const updateTemplateVariableSchema = z.object({
  key: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Template Variable ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const templateVariableIdParamsSchema = z.object({
  id: uuidSchema
});

// ==================== Query Params ====================

/**
 * List template variables query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with template-variable-specific filters
 */
const listTemplateVariablesQuerySchema = listQuerySchema.extend({
  template_id: uuidSchema.optional(),
  key: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createTemplateVariableSchema,
  updateTemplateVariableSchema,
  templateVariableIdParamsSchema,
  listTemplateVariablesQuerySchema
};
