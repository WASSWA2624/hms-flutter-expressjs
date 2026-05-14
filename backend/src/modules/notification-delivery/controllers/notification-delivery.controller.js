/**
 * NotificationDelivery controller
 *
 * @module modules/notification-delivery/controllers
 * @description Request handlers for notification-delivery endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const notificationDeliveryService = require('@services/notification-delivery/notification-delivery.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List notification-deliveries with pagination
 * GET /api/v1/notification-deliveries
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listNotificationDeliveries = asyncHandler(async (req, res) => {
  const {
    notification_id,
    channel,
    status,
    retryable,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    notification_id,
    channel,
    status,
    retryable,
    search,
  };

  const result = await notificationDeliveryService.listNotificationDeliveries(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.notification_delivery.list.success', result.notificationDeliveries, result.pagination);
});

/**
 * Get notification-delivery by ID
 * GET /api/v1/notification-deliveries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getNotificationDeliveryById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const notificationDelivery = await notificationDeliveryService.getNotificationDeliveryById(
    id,
    req.user
  );

  sendSuccess(res, 200, 'messages.notification_delivery.get.success', notificationDelivery);
});

/**
 * Create new notification-delivery
 * POST /api/v1/notification-deliveries
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createNotificationDelivery = asyncHandler(async (req, res) => {
  const notificationDelivery = await notificationDeliveryService.createNotificationDelivery(
    req.body,
    req.user,
    req.ip
  );

  sendSuccess(res, 201, 'messages.notification_delivery.create.success', notificationDelivery);
});

/**
 * Update notification-delivery
 * PUT /api/v1/notification-deliveries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateNotificationDelivery = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const notificationDelivery = await notificationDeliveryService.updateNotificationDelivery(
    id,
    req.body,
    req.user,
    req.ip
  );

  sendSuccess(res, 200, 'messages.notification_delivery.update.success', notificationDelivery);
});

/**
 * Delete notification-delivery (soft delete)
 * DELETE /api/v1/notification-deliveries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteNotificationDelivery = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await notificationDeliveryService.deleteNotificationDelivery(id, req.user, req.ip);

  sendNoContent(res);
});

module.exports = {
  listNotificationDeliveries,
  getNotificationDeliveryById,
  createNotificationDelivery,
  updateNotificationDelivery,
  deleteNotificationDelivery
};
