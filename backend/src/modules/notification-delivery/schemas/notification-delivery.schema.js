/**
 * NotificationDelivery module validation schemas
 *
 * @module modules/notification-delivery/schemas
 * @description Zod validation schemas for notification-delivery endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  booleanStringSchema,
  listQuerySchema,
  uuidSchema,
} = require('@lib/validation/zod');

const RESOURCE_FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;
const resourceFriendlyIdSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .regex(RESOURCE_FRIENDLY_ID_REGEX, 'Invalid identifier format')
  .transform((value) => value.toUpperCase());
const resourceIdentifierSchema = z.union([uuidSchema, resourceFriendlyIdSchema]);

const COMMUNICATION_CHANNELS = [
  'EMAIL',
  'SMS',
  'PUSH',
  'WHATSAPP',
  'IN_APP',
  'TELEGRAM',
  'TIKTOK',
  'INSTAGRAM',
  'FACEBOOK',
  'LINKEDIN',
  'X',
  'YOUTUBE',
  'PINTEREST',
  'REDDIT',
  'DISCORD',
  'CALL',
  'OTHER',
];
const NOTIFICATION_DELIVERY_STATUSES = [
  'QUEUED',
  'SENDING',
  'SENT',
  'DELIVERED',
  'FAILED',
  'READ',
];
const DELIVERY_SORT_FIELDS = ['created_at', 'updated_at', 'sent_at', 'delivered_at', 'status', 'channel'];

const channelSchema = z.enum(COMMUNICATION_CHANNELS);
const deliveryStatusSchema = z.enum(NOTIFICATION_DELIVERY_STATUSES);

// ==================== Body Schemas ====================

/**
 * Create notification-delivery body validation
 * Used for POST /notification-deliveries endpoint
 */
const createNotificationDeliverySchema = z.object({
  notification_id: resourceIdentifierSchema,
  channel: channelSchema,
  status: deliveryStatusSchema.optional(),
  recipient_target: z.string().trim().max(255).optional().nullable(),
  provider_name: z.string().trim().max(120).optional().nullable(),
  attempt_count: z.coerce.number().int().min(0).optional(),
  last_attempt_at: z.string().datetime().optional().nullable(),
  sent_at: z.string().datetime().optional().nullable(),
  delivered_at: z.string().datetime().optional().nullable(),
  failed_at: z.string().datetime().optional().nullable(),
  error_message: z.string().trim().max(2000).optional().nullable(),
  retryable: z.boolean().optional(),
});

/**
 * Update notification-delivery body validation
 * Used for PUT /notification-deliveries/:id endpoint
 * All fields optional for partial updates
 */
const updateNotificationDeliverySchema = z.object({
  notification_id: resourceIdentifierSchema.optional(),
  channel: channelSchema.optional(),
  status: deliveryStatusSchema.optional(),
  recipient_target: z.string().trim().max(255).optional().nullable(),
  provider_name: z.string().trim().max(120).optional().nullable(),
  attempt_count: z.coerce.number().int().min(0).optional(),
  last_attempt_at: z.string().datetime().optional().nullable(),
  sent_at: z.string().datetime().optional().nullable(),
  delivered_at: z.string().datetime().optional().nullable(),
  failed_at: z.string().datetime().optional().nullable(),
  error_message: z.string().trim().max(2000).optional().nullable(),
  retryable: z.boolean().optional(),
});

// ==================== URL Params ====================

/**
 * NotificationDelivery ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const notificationDeliveryIdParamsSchema = z.object({
  id: resourceIdentifierSchema,
});

// ==================== Query Params ====================

/**
 * List notification-deliveries query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with notification-delivery-specific filters
 */
const listNotificationDeliveriesQuerySchema = listQuerySchema.extend({
  sort_by: z.enum(DELIVERY_SORT_FIELDS).optional(),
  notification_id: resourceIdentifierSchema.optional(),
  channel: channelSchema.optional(),
  status: deliveryStatusSchema.optional(),
  retryable: booleanStringSchema.optional(),
  include_notification: booleanStringSchema.optional(),
  search: z.string().trim().max(120).optional(),
});

module.exports = {
  createNotificationDeliverySchema,
  updateNotificationDeliverySchema,
  notificationDeliveryIdParamsSchema,
  listNotificationDeliveriesQuerySchema,
  COMMUNICATION_CHANNELS,
  NOTIFICATION_DELIVERY_STATUSES,
};
