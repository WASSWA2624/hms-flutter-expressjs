/**
 * Lab order module validation schemas
 *
 * @module modules/lab-order/schemas
 * @description Zod validation schemas for lab order endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create lab order body validation
 * Used for POST /lab-orders endpoint
 */
const labOrderStatusSchema = z.enum(['ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED']);

const MAX_REQUESTED_LAB_TESTS = 5000;
const MAX_REQUESTED_LAB_PANELS = 5000;
const labTestResultKindSchema = z.enum(['NUMERIC', 'QUALITATIVE', 'TEXT']);

const labOrderNewTestSchema = z.object({
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().max(80).optional().nullable(),
  category: z.string().trim().min(1).max(80),
  specimen_type: z.string().trim().min(1).max(80),
  result_kind: labTestResultKindSchema.optional().default('NUMERIC'),
  unit: z.string().trim().max(40).optional().nullable(),
  description: z.string().trim().max(255).optional().nullable()
});

const labOrderRequestedTestSchema = z
  .object({
    lab_test_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    new_test: labOrderNewTestSchema.optional().nullable()
  })
  .superRefine((value, ctx) => {
    if (value.lab_test_id || value.new_test?.name) return;
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['lab_test_id'],
      message: 'errors.validation.required'
    });
  });

const labOrderRequestedPanelSchema = z.object({
  lab_panel_id: uuidOrFriendlyIdentifierSchema
});

const createLabOrderSchema = z
  .object({
    encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    patient_id: uuidOrFriendlyIdentifierSchema,
    status: labOrderStatusSchema.optional().default('ORDERED'),
    ordered_at: z.string().datetime().optional(),
    requested_tests: z.array(labOrderRequestedTestSchema).max(MAX_REQUESTED_LAB_TESTS).optional(),
    requested_panels: z.array(labOrderRequestedPanelSchema).max(MAX_REQUESTED_LAB_PANELS).optional()
  })
  .superRefine((value, ctx) => {
    const requestedTests = Array.isArray(value.requested_tests) ? value.requested_tests : [];
    const requestedPanels = Array.isArray(value.requested_panels) ? value.requested_panels : [];
    if (requestedTests.length || requestedPanels.length) return;
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['requested_tests'],
      message: 'errors.validation.required'
    });
  });

/**
 * Update lab order body validation
 * Used for PUT /lab-orders/:id endpoint
 * All fields optional for partial updates
 */
const updateLabOrderSchema = z.object({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: labOrderStatusSchema.optional(),
  ordered_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Lab order ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const labOrderIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List lab orders query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with lab-order-specific filters
 */
const listLabOrdersQuerySchema = listQuerySchema.extend({
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: labOrderStatusSchema.optional(),
  ordered_at_from: z.string().datetime().optional(),
  ordered_at_to: z.string().datetime().optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createLabOrderSchema,
  updateLabOrderSchema,
  labOrderIdParamsSchema,
  listLabOrdersQuerySchema
};
