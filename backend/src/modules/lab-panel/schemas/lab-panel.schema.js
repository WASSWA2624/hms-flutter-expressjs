/**
 * Lab panel module validation schemas
 *
 * @module modules/lab-panel/schemas
 * @description Zod validation schemas for lab panel endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema, 
  listQuerySchema
} = require('@lib/validation/zod');

const optionalTrimmedString = (maxLength) =>
  z.string().trim().min(1).max(maxLength).optional().nullable();

const labPanelItemSchema = z.object({
  lab_test_id: uuidOrFriendlyIdentifierSchema,
  is_required: z.boolean().optional(),
  instructions: optionalTrimmedString(255),
});

const withUniquePanelItems = (schema) =>
  schema.superRefine((value, ctx) => {
    if (!Array.isArray(value.panel_items)) return;
    const seen = new Set();
    value.panel_items.forEach((entry, index) => {
      const identifier = String(entry?.lab_test_id || '').trim().toUpperCase();
      if (!identifier) return;
      if (seen.has(identifier)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Each lab test can only appear once in a panel.',
          path: ['panel_items', index, 'lab_test_id'],
        });
        return;
      }
      seen.add(identifier);
    });
  });

// ==================== Body Schemas ====================

/**
 * Create lab panel body validation
 * Used for POST /lab-panels endpoint
 */
const createLabPanelSchema = withUniquePanelItems(z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  name: z.string().trim().min(1).max(255),
  code: optionalTrimmedString(80),
  category: optionalTrimmedString(80),
  description: optionalTrimmedString(255),
  panel_items: z.array(labPanelItemSchema).min(1).max(25).optional()
}));

/**
 * Update lab panel body validation
 * Used for PUT /lab-panels/:id endpoint
 * All fields optional for partial updates
 */
const updateLabPanelSchema = withUniquePanelItems(z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: optionalTrimmedString(80),
  category: optionalTrimmedString(80),
  description: optionalTrimmedString(255),
  panel_items: z.array(labPanelItemSchema).min(1).max(25).optional()
}));

// ==================== URL Params ====================

/**
 * Lab panel ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const labPanelIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List lab panels query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with lab panel-specific filters
 */
const listLabPanelsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  category: z.string().trim().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createLabPanelSchema,
  updateLabPanelSchema,
  labPanelIdParamsSchema,
  listLabPanelsQuerySchema
};
