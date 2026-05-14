/**
 * Shift module validation schemas
 *
 * @module modules/shift/schemas
 * @description Zod validation schemas for shift endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
  isoDateSchema
} = require('@lib/validation/zod');

// ==================== Body Schemas ====================

/**
 * Create shift body validation
 * Used for POST /shifts endpoint
 */
const createShiftSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']),
  status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).default('SCHEDULED'),
  start_time: isoDateSchema,
  end_time: isoDateSchema
}).refine((data) => {
  const start = new Date(data.start_time);
  const end = new Date(data.end_time);
  return end > start;
}, {
  message: 'end_time must be after start_time',
  path: ['end_time']
});

/**
 * Update shift body validation
 * Used for PUT /shifts/:id endpoint
 * All fields optional for partial updates
 */
const updateShiftSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
  status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).optional(),
  start_time: isoDateSchema.optional(),
  end_time: isoDateSchema.optional()
}).refine((data) => {
  if (data.start_time && data.end_time) {
    const start = new Date(data.start_time);
    const end = new Date(data.end_time);
    return end > start;
  }
  return true;
}, {
  message: 'end_time must be after start_time',
  path: ['end_time']
});

/**
 * Publish shift body validation
 * Used for POST /shifts/:id/publish endpoint
 */
const publishShiftSchema = z.object({
  notify_staff: z.boolean().default(true)
});

// ==================== URL Params ====================

/**
 * Shift ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and POST /:id/publish endpoints
 */
const shiftIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List shifts query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with shift-specific filters
 */
const listShiftsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  shift_type: z.enum(['DAY', 'NIGHT', 'SWING', 'ON_CALL']).optional(),
  status: z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']).optional(),
  start_time_from: z.string().datetime().optional(),
  start_time_to: z.string().datetime().optional(),
  end_time_from: z.string().datetime().optional(),
  end_time_to: z.string().datetime().optional()
});

module.exports = {
  createShiftSchema,
  updateShiftSchema,
  publishShiftSchema,
  shiftIdParamsSchema,
  listShiftsQuerySchema
};
