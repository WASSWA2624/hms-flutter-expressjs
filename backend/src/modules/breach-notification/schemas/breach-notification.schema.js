/**
 * Breach notification module validation schemas
 *
 * @module modules/breach-notification/schemas
 * @description Zod validation schemas for breach notification endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema,
} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Breach severity enum (matches Prisma schema)
 * Enum values: LOW, MEDIUM, HIGH, CRITICAL
 */
const breachSeverityEnum = z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);

/**
 * Breach status enum (matches Prisma schema)
 * Enum values: OPEN, INVESTIGATING, RESOLVED, REPORTED
 */
const breachStatusEnum = z.enum(['OPEN', 'INVESTIGATING', 'RESOLVED', 'REPORTED']);

// ==================== Body Schemas ====================

/**
 * Create breach notification body validation
 * Used for POST /breach-notifications endpoint
 */
const createBreachNotificationSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  severity: breachSeverityEnum,
  status: breachStatusEnum.optional().default('OPEN'),
  description: z.string().trim().optional().nullable(),
  reported_at: z.string().datetime().optional(),
});

/**
 * Update breach notification body validation
 * Used for PUT /breach-notifications/:id endpoint
 * All fields optional for partial updates
 */
const updateBreachNotificationSchema = z.object({
  severity: breachSeverityEnum.optional(),
  status: breachStatusEnum.optional(),
  description: z.string().trim().optional().nullable(),
  reported_at: z.string().datetime().optional(),
  resolved_at: z.string().datetime().optional().nullable()
});

/**
 * Resolve breach notification body validation
 * Used for POST /breach-notifications/:id/resolve endpoint
 */
const resolveBreachNotificationSchema = z.object({
  resolved_at: z.string().datetime().optional()
});

// ==================== URL Params ====================

/**
 * Breach notification ID URL parameter validation
 * Used for GET /:id, PUT /:id, DELETE /:id, and POST /:id/resolve endpoints
 */
const breachNotificationIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

// ==================== Query Params ====================

/**
 * List breach notifications query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with breach-notification-specific filters
 */
const listBreachNotificationsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  severity: breachSeverityEnum.optional(),
  status: breachStatusEnum.optional(),
  search: z.string().trim().max(120).optional(),
  from_date: z.string().datetime().optional(),
  to_date: z.string().datetime().optional(),
});

module.exports = {
  createBreachNotificationSchema,
  updateBreachNotificationSchema,
  resolveBreachNotificationSchema,
  breachNotificationIdParamsSchema,
  listBreachNotificationsQuerySchema,
  breachSeverityEnum,
  breachStatusEnum
};
