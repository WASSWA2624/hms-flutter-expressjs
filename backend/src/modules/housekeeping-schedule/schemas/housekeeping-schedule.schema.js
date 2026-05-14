/**
 * Housekeeping schedule module validation schemas
 *
 * @module modules/housekeeping-schedule/schemas
 * @description Zod validation schemas for housekeeping schedule endpoints.
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
 * Create housekeeping schedule body validation
 * Used for POST /housekeeping-schedules endpoint
 */
const createHousekeepingScheduleSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  frequency: z.string().trim().min(1).max(80).optional().nullable(),
  start_date: isoDateSchema.optional().nullable(),
  end_date: isoDateSchema.optional().nullable()
});

/**
 * Update housekeeping schedule body validation
 * Used for PUT /housekeeping-schedules/:id endpoint
 * All fields optional for partial updates
 */
const updateHousekeepingScheduleSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  frequency: z.string().trim().min(1).max(80).optional().nullable(),
  start_date: isoDateSchema.optional().nullable(),
  end_date: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * Housekeeping schedule ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const housekeepingScheduleIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List housekeeping schedules query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with housekeeping schedule-specific filters
 */
const listHousekeepingSchedulesQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  room_id: uuidOrFriendlyIdentifierSchema.optional(),
  frequency: z.string().trim().optional()
});

module.exports = {
  createHousekeepingScheduleSchema,
  updateHousekeepingScheduleSchema,
  housekeepingScheduleIdParamsSchema,
  listHousekeepingSchedulesQuerySchema
};
