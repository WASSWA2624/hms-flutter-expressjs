/**
 * Notification delivery routes
 *
 * @module modules/notification-delivery/routes
 * @description Notification delivery endpoints mounted at /api/v1/notification-deliveries
 */

const express = require('express');
const router = express.Router();
const notificationDeliveryController = require('@controllers/notification-delivery/notification-delivery.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createNotificationDeliverySchema,
  updateNotificationDeliverySchema,
  notificationDeliveryIdParamsSchema,
  listNotificationDeliveriesQuerySchema
} = require('@validations/notification-delivery/notification-delivery.schema');

router.get(
  '/',
  validateRequest({ query: listNotificationDeliveriesQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  notificationDeliveryController.listNotificationDeliveries
);

router.get(
  '/:id',
  validateRequest({ params: notificationDeliveryIdParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  notificationDeliveryController.getNotificationDeliveryById
);

router.post(
  '/',
  validateRequest({ body: createNotificationDeliverySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationDeliveryController.createNotificationDelivery
);

router.put(
  '/:id',
  validateRequest({
    params: notificationDeliveryIdParamsSchema,
    body: updateNotificationDeliverySchema
  }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  notificationDeliveryController.updateNotificationDelivery
);

router.delete(
  '/:id',
  validateRequest({ params: notificationDeliveryIdParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  notificationDeliveryController.deleteNotificationDelivery
);

module.exports = router;
