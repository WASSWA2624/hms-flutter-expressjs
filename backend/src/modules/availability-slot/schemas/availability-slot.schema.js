/**
 * Availability slot module validation schemas
 *
 * @module modules/availability-slot/schemas
 * @description Zod validation schemas for availability slot endpoints.
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
 * Create availability slot body validation
 * Used for POST /availability-slots endpoint
 */
const createAvailabilitySlotSchema = z.object({
  schedule_id: uuidOrFriendlyIdentifierSchema,
  override_date: z.string().trim().datetime().optional().nullable(),
  start_time: z.string().trim().datetime(),
  end_time: z.string().trim().datetime(),
  is_available: z.boolean().optional()
});

/**
 * Update availability slot body validation
 * Used for PUT /availability-slots/:id endpoint
 * All fields optional for partial updates
 */
const updateAvailabilitySlotSchema = z.object({
  schedule_id: uuidOrFriendlyIdentifierSchema.optional(),
  override_date: z.string().trim().datetime().optional().nullable(),
  start_time: z.string().trim().datetime().optional(),
  end_time: z.string().trim().datetime().optional(),
  is_available: z.boolean().optional()
});

// ==================== URL Params ====================

/**
 * Availability slot ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const availabilitySlotIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List availability slots query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with availability slot-specific filters
 */
const listAvailabilitySlotsQuerySchema = listQuerySchema.extend({
  schedule_id: uuidOrFriendlyIdentifierSchema.optional(),
  override_date: z.string().trim().datetime().optional(),
  is_available: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => {
      if (value === undefined) return undefined;
      return value === 'true';
    })
});

module.exports = {
  createAvailabilitySlotSchema,
  updateAvailabilitySlotSchema,
  availabilitySlotIdParamsSchema,
  listAvailabilitySlotsQuerySchema
};
