/**
 * Notification routes
 *
 * @module modules/notification/routes
 * @description Notification endpoints mounted at /api/v1/notifications
 */

const express = require('express');
const router = express.Router();
const notificationController = require('@controllers/notification/notification.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  bulkNotificationMutationSchema,
  createNotificationSchema,
  notificationHubQuerySchema,
  notificationMetricsQuerySchema,
  updateNotificationSchema,
  notificationIdParamsSchema,
  listNotificationsQuerySchema,
} = require('@validations/notification/notification.schema');

router.get(
  '/',
  validateRequest({ query: listNotificationsQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  notificationController.listNotifications
);

router.get(
  '/hub',
  validateRequest({ query: notificationHubQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  notificationController.getNotificationHub
);

router.get(
  '/metrics',
  validateRequest({ query: notificationMetricsQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  notificationController.getNotificationMetrics
);

router.post(
  '/bulk/read',
  validateRequest({ body: bulkNotificationMutationSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationController.bulkMarkNotificationsRead
);

router.post(
  '/bulk/unread',
  validateRequest({ body: bulkNotificationMutationSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationController.bulkMarkNotificationsUnread
);

router.post(
  '/bulk/archive',
  validateRequest({ body: bulkNotificationMutationSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  notificationController.bulkArchiveNotifications
);

router.get(
  '/:id',
  validateRequest({ params: notificationIdParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  notificationController.getNotificationById
);

router.post(
  '/',
  validateRequest({ body: createNotificationSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationController.createNotification
);

router.post(
  '/:id/read',
  validateRequest({ params: notificationIdParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationController.markNotificationRead
);

router.post(
  '/:id/unread',
  validateRequest({ params: notificationIdParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationController.markNotificationUnread
);

router.put(
  '/:id',
  validateRequest({ params: notificationIdParamsSchema, body: updateNotificationSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationController.updateNotification
);

router.delete(
  '/:id',
  validateRequest({ params: notificationIdParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  notificationController.deleteNotification
);

module.exports = router;
