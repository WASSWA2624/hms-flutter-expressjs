/**
 * Breach notification routes
 *
 * @module modules/breach-notification/routes
 * @description Breach notification endpoints mounted at /api/v1/breach-notifications
 */

const express = require('express');
const router = express.Router();
const breachNotificationController = require('@controllers/breach-notification/breach-notification.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createBreachNotificationSchema,
  updateBreachNotificationSchema,
  resolveBreachNotificationSchema,
  breachNotificationIdParamsSchema,
  listBreachNotificationsQuerySchema,
} = require('@validations/breach-notification/breach-notification.schema');

const COMPLIANCE_READ_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const COMPLIANCE_WRITE_SCOPES = COMPLIANCE_READ_SCOPES;

router.get(
  '/',
  validateRequest({ query: listBreachNotificationsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  breachNotificationController.listBreachNotifications
);

router.get(
  '/:id',
  validateRequest({ params: breachNotificationIdParamsSchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  breachNotificationController.getBreachNotificationById
);

router.post(
  '/',
  validateRequest({ body: createBreachNotificationSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  breachNotificationController.createBreachNotification
);

router.put(
  '/:id',
  validateRequest({ params: breachNotificationIdParamsSchema, body: updateBreachNotificationSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  breachNotificationController.updateBreachNotification
);

router.post(
  '/:id/resolve',
  validateRequest({ params: breachNotificationIdParamsSchema, body: resolveBreachNotificationSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  breachNotificationController.resolveBreachNotification
);

module.exports = router;
