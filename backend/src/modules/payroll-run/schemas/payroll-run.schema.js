/**
 * Payroll run module validation schemas
 *
 * @module modules/payroll-run/schemas
 * @description Zod validation schemas for payroll run endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Payroll status enum (matches Prisma schema)
 * Enum values: DRAFT, PROCESSED, PAID, CANCELLED
 */
const payrollStatusEnum = z.enum(['DRAFT', 'PROCESSED', 'PAID', 'CANCELLED']);

// ==================== Body Schemas ====================

/**
 * Create payroll run body validation
 * Used for POST /payroll-runs endpoint
 */
const createPayrollRunSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  period_start: z.coerce.date(),
  period_end: z.coerce.date(),
  status: payrollStatusEnum.optional().default('DRAFT')
}).refine((data) => data.period_end > data.period_start, {
  message: 'errors.validation.period_end_after_start',
  path: ['period_end']
});

/**
 * Update payroll run body validation
 * Used for PUT /payroll-runs/:id endpoint
 * All fields optional for partial updates
 */
const updatePayrollRunSchema = z.object({
  period_start: z.coerce.date().optional(),
  period_end: z.coerce.date().optional(),
  status: payrollStatusEnum.optional()
}).refine((data) => {
  if (data.period_start && data.period_end) {
    return data.period_end > data.period_start;
  }
  return true;
}, {
  message: 'errors.validation.period_end_after_start',
  path: ['period_end']
});

// ==================== URL Params ====================

/**
 * Payroll run ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const payrollRunIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List payroll runs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with payroll-run-specific filters
 */
const listPayrollRunsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: payrollStatusEnum.optional(),
  period_start_from: z.coerce.date().optional(),
  period_start_to: z.coerce.date().optional(),
  period_end_from: z.coerce.date().optional(),
  period_end_to: z.coerce.date().optional()
});

module.exports = {
  createPayrollRunSchema,
  updatePayrollRunSchema,
  payrollRunIdParamsSchema,
  listPayrollRunsQuerySchema,
  payrollStatusEnum
};
