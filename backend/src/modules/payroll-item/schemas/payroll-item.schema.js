/**
 * Payroll item module validation schemas
 *
 * @module modules/payroll-item/schemas
 * @description Zod validation schemas for payroll item endpoints.
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
 * Create payroll item body validation
 * Used for POST /payroll-items endpoint
 */
const createPayrollItemSchema = z.object({
  payroll_run_id: uuidOrFriendlyIdentifierSchema,
  staff_profile_id: uuidOrFriendlyIdentifierSchema,
  amount: z.number().min(0),
  currency: z.string().trim().min(1).max(10)
});

/**
 * Update payroll item body validation
 * Used for PUT /payroll-items/:id endpoint
 * All fields optional for partial updates
 */
const updatePayrollItemSchema = z.object({
  payroll_run_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  amount: z.number().min(0).optional(),
  currency: z.string().trim().min(1).max(10).optional()
});

// ==================== URL Params ====================

/**
 * Payroll item ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const payrollItemIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List payroll items query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with payroll-item-specific filters
 */
const listPayrollItemsQuerySchema = listQuerySchema.extend({
  payroll_run_id: uuidOrFriendlyIdentifierSchema.optional(),
  staff_profile_id: uuidOrFriendlyIdentifierSchema.optional(),
  currency: z.string().trim().optional(),
  amount_min: z.coerce.number().min(0).optional(),
  amount_max: z.coerce.number().min(0).optional()
});

module.exports = {
  createPayrollItemSchema,
  updatePayrollItemSchema,
  payrollItemIdParamsSchema,
  listPayrollItemsQuerySchema
};
