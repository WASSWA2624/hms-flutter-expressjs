/**
 * Notification controller
 *
 * @module modules/notification/controllers
 * @description Request handlers for notification endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const notificationService = require('@services/notification/notification.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List notifications with pagination
 * GET /api/v1/notifications
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listNotifications = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    user_id,
    notification_type,
    priority,
    is_read,
    search,
    channel,
    delivery_status,
    from_date,
    to_date,
    include_deliveries,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    tenant_id,
    user_id,
    notification_type,
    priority,
    is_read,
    search,
    channel,
    delivery_status,
    from_date,
    to_date,
    include_deliveries,
  };

  const result = await notificationService.listNotifications(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.notification.list.success', result.notifications, result.pagination);
});

/**
 * Get notification hub data
 * GET /api/v1/notifications/hub
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getNotificationHub = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc',
    ...filters
  } = req.query;

  const data = await notificationService.getNotificationHub(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user
  );

  sendSuccess(res, 200, 'messages.notification.hub.success', data);
});

/**
 * Get notification metrics
 * GET /api/v1/notifications/metrics
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getNotificationMetrics = asyncHandler(async (req, res) => {
  const data = await notificationService.getNotificationMetrics(req.query, req.user);
  sendSuccess(res, 200, 'messages.notification.metrics.success', data);
});

/**
 * Get notification by ID
 * GET /api/v1/notifications/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getNotificationById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const notification = await notificationService.getNotificationById(id, req.user);

  sendSuccess(res, 200, 'messages.notification.get.success', notification);
});

/**
 * Create new notification
 * POST /api/v1/notifications
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createNotification = asyncHandler(async (req, res) => {
  const notification = await notificationService.createNotification(req.body, req.user, req.ip);

  sendSuccess(res, 201, 'messages.notification.create.success', notification);
});

/**
 * Update notification
 * PUT /api/v1/notifications/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateNotification = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const notification = await notificationService.updateNotification(id, req.body, req.user, req.ip);

  sendSuccess(res, 200, 'messages.notification.update.success', notification);
});

/**
 * Delete notification (soft delete)
 * DELETE /api/v1/notifications/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteNotification = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await notificationService.deleteNotification(id, req.user, req.ip);

  sendNoContent(res);
});

/**
 * Mark notification as read
 * POST /api/v1/notifications/:id/read
 */
const markNotificationRead = asyncHandler(async (req, res) => {
  const notification = await notificationService.setNotificationReadState(
    req.params.id,
    true,
    req.user,
    req.ip
  );
  sendSuccess(res, 200, 'messages.notification.mark_read.success', notification);
});

/**
 * Mark notification as unread
 * POST /api/v1/notifications/:id/unread
 */
const markNotificationUnread = asyncHandler(async (req, res) => {
  const notification = await notificationService.setNotificationReadState(
    req.params.id,
    false,
    req.user,
    req.ip
  );
  sendSuccess(res, 200, 'messages.notification.mark_unread.success', notification);
});

/**
 * Bulk mark notifications as read
 * POST /api/v1/notifications/bulk/read
 */
const bulkMarkNotificationsRead = asyncHandler(async (req, res) => {
  const result = await notificationService.bulkUpdateReadState(
    req.body.ids,
    true,
    req.user,
    req.ip
  );
  sendSuccess(res, 200, 'messages.notification.bulk_mark_read.success', result);
});

/**
 * Bulk mark notifications as unread
 * POST /api/v1/notifications/bulk/unread
 */
const bulkMarkNotificationsUnread = asyncHandler(async (req, res) => {
  const result = await notificationService.bulkUpdateReadState(
    req.body.ids,
    false,
    req.user,
    req.ip
  );
  sendSuccess(res, 200, 'messages.notification.bulk_mark_unread.success', result);
});

/**
 * Bulk archive notifications
 * POST /api/v1/notifications/bulk/archive
 */
const bulkArchiveNotifications = asyncHandler(async (req, res) => {
  const result = await notificationService.bulkArchiveNotifications(req.body.ids, req.user, req.ip);
  sendSuccess(res, 200, 'messages.notification.bulk_archive.success', result);
});

module.exports = {
  listNotifications,
  getNotificationHub,
  getNotificationMetrics,
  getNotificationById,
  createNotification,
  updateNotification,
  deleteNotification,
  markNotificationRead,
  markNotificationUnread,
  bulkMarkNotificationsRead,
  bulkMarkNotificationsUnread,
  bulkArchiveNotifications,
};
