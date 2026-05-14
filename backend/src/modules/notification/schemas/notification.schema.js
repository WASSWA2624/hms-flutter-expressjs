/**
 * Notification module validation schemas
 *
 * @module modules/notification/schemas
 * @description Zod validation schemas for notification endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  booleanStringSchema,
  dateStringSchema,
  listQuerySchema,
  uuidSchema,
} = require('@lib/validation/zod');

const RESOURCE_FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;
const BULK_MUTATION_MAX_IDS = 200;

const NOTIFICATION_TYPES = [
  'SYSTEM',
  'APPOINTMENT',
  'BILLING',
  'LAB',
  'PHARMACY',
  'EMERGENCY',
  'OTHER',
];
const NOTIFICATION_PRIORITIES = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
const NOTIFICATION_REQUEST_CHANNELS = ['EMAIL', 'IN_APP'];
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
const HUB_SORT_FIELDS = ['created_at', 'updated_at', 'read_at', 'priority', 'notification_type'];

const resourceFriendlyIdSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .regex(RESOURCE_FRIENDLY_ID_REGEX, 'Invalid identifier format')
  .transform((value) => value.toUpperCase());
const resourceIdentifierSchema = z.union([uuidSchema, resourceFriendlyIdSchema]);
const notificationTypeSchema = z.enum(NOTIFICATION_TYPES);
const notificationPrioritySchema = z.enum(NOTIFICATION_PRIORITIES);
const notificationRequestChannelSchema = z.enum(NOTIFICATION_REQUEST_CHANNELS);
const communicationChannelSchema = z.enum(COMMUNICATION_CHANNELS);
const deliveryStatusSchema = z.enum(NOTIFICATION_DELIVERY_STATUSES);

const optionalTrimmedString = (max = 255) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .nullable();

const notificationFiltersSchema = z.object({
  tenant_id: resourceIdentifierSchema.optional(),
  user_id: resourceIdentifierSchema.optional(),
  notification_type: notificationTypeSchema.optional(),
  priority: notificationPrioritySchema.optional(),
  is_read: booleanStringSchema.optional(),
  search: z.string().trim().max(120).optional(),
  channel: communicationChannelSchema.optional(),
  delivery_status: deliveryStatusSchema.optional(),
  from_date: dateStringSchema.optional(),
  to_date: dateStringSchema.optional(),
});

// ==================== Body Schemas ====================

/**
 * Create notification body validation
 * Used for POST /notifications endpoint
 */
const createNotificationSchema = z.object({
  tenant_id: resourceIdentifierSchema,
  user_id: resourceIdentifierSchema.optional().nullable(),
  template_id: resourceIdentifierSchema.optional().nullable(),
  delivery_channels: z.array(notificationRequestChannelSchema).min(1).max(5).optional(),
  notification_type: notificationTypeSchema,
  priority: notificationPrioritySchema,
  title: z.string().trim().min(1).max(255),
  message: z.string().trim().min(1),
  target_path: optionalTrimmedString(255),
  context_type: optionalTrimmedString(80),
  context_public_id: optionalTrimmedString(64),
  read_at: z.string().datetime().optional().nullable(),
});

/**
 * Update notification body validation
 * Used for PUT /notifications/:id endpoint
 * All fields optional for partial updates
 */
const updateNotificationSchema = z.object({
  tenant_id: resourceIdentifierSchema.optional(),
  user_id: resourceIdentifierSchema.optional().nullable(),
  template_id: resourceIdentifierSchema.optional().nullable(),
  notification_type: notificationTypeSchema.optional(),
  priority: notificationPrioritySchema.optional(),
  title: z.string().trim().min(1).max(255).optional(),
  message: z.string().trim().min(1).optional(),
  target_path: optionalTrimmedString(255),
  context_type: optionalTrimmedString(80),
  context_public_id: optionalTrimmedString(64),
  read_at: z.string().datetime().optional().nullable(),
});

// ==================== URL Params ====================

/**
 * Notification ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const notificationIdParamsSchema = z.object({
  id: resourceIdentifierSchema,
});

// ==================== Query Params ====================

/**
 * List notifications query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with notification-specific filters
 */
const listNotificationsQuerySchema = listQuerySchema
  .extend({
    sort_by: z.enum(HUB_SORT_FIELDS).optional(),
    include_deliveries: booleanStringSchema.optional(),
  })
  .merge(notificationFiltersSchema);

const notificationHubQuerySchema = listNotificationsQuerySchema;

const notificationMetricsQuerySchema = notificationFiltersSchema;

const bulkNotificationMutationSchema = z.object({
  ids: z.array(resourceIdentifierSchema).min(1).max(BULK_MUTATION_MAX_IDS),
});

module.exports = {
  createNotificationSchema,
  updateNotificationSchema,
  notificationIdParamsSchema,
  listNotificationsQuerySchema,
  notificationHubQuerySchema,
  notificationMetricsQuerySchema,
  bulkNotificationMutationSchema,
  NOTIFICATION_TYPES,
  NOTIFICATION_PRIORITIES,
  NOTIFICATION_DELIVERY_STATUSES,
  HUB_SORT_FIELDS,
};
