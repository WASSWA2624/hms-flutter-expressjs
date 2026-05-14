/**
 * Housekeeping task module validation schemas
 *
 * @module modules/housekeeping-task/schemas
 * @description Zod validation schemas for housekeeping task endpoints.
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
 * Create housekeeping task body validation
 * Used for POST /housekeeping-tasks endpoint
 */
const createHousekeepingTaskSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  assigned_to_staff_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
  scheduled_at: isoDateSchema.optional().nullable(),
  completed_at: isoDateSchema.optional().nullable()
});

/**
 * Update housekeeping task body validation
 * Used for PUT /housekeeping-tasks/:id endpoint
 * All fields optional for partial updates
 */
const updateHousekeepingTaskSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  assigned_to_staff_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  status: z.enum(['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional(),
  scheduled_at: isoDateSchema.optional().nullable(),
  completed_at: isoDateSchema.optional().nullable()
});

// ==================== URL Params ====================

/**
 * Housekeeping task ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const housekeepingTaskIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List housekeeping tasks query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with housekeeping task-specific filters
 */
const listHousekeepingTasksQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  room_id: uuidOrFriendlyIdentifierSchema.optional(),
  assigned_to_staff_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional()
});

module.exports = {
  createHousekeepingTaskSchema,
  updateHousekeepingTaskSchema,
  housekeepingTaskIdParamsSchema,
  listHousekeepingTasksQuerySchema
};
