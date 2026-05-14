/**
 * Module subscription routes
 *
 * @module modules/module-subscription/routes
 * @description Module subscription endpoints mounted at /api/v1/module-subscriptions
 */

const express = require('express');
const moduleSubscriptionController = require('@controllers/module-subscription/module-subscription.controller');
const { PERMISSIONS } = require('@config/permissions');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const {
  createModuleSubscriptionSchema,
  updateModuleSubscriptionSchema,
  moduleSubscriptionActivationSchema,
  moduleSubscriptionIdParamsSchema,
  listModuleSubscriptionsQuerySchema,
} = require('@validations/module-subscription/module-subscription.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listModuleSubscriptionsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  moduleSubscriptionController.listModuleSubscriptions
);

router.get(
  '/:id',
  validateRequest({ params: moduleSubscriptionIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  moduleSubscriptionController.getModuleSubscriptionById
);

router.post(
  '/',
  validateRequest({ body: createModuleSubscriptionSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  moduleSubscriptionController.createModuleSubscription
);

router.put(
  '/:id',
  validateRequest({
    params: moduleSubscriptionIdParamsSchema,
    body: updateModuleSubscriptionSchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  moduleSubscriptionController.updateModuleSubscription
);

router.delete(
  '/:id',
  validateRequest({ params: moduleSubscriptionIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_DELETE, 'permission'),
  moduleSubscriptionController.deleteModuleSubscription
);

router.post(
  '/:id/activate',
  validateRequest({
    params: moduleSubscriptionIdParamsSchema,
    body: moduleSubscriptionActivationSchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  moduleSubscriptionController.activateModuleSubscription
);

router.post(
  '/:id/deactivate',
  validateRequest({
    params: moduleSubscriptionIdParamsSchema,
    body: moduleSubscriptionActivationSchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  moduleSubscriptionController.deactivateModuleSubscription
);

router.get(
  '/:id/eligibility-check',
  validateRequest({ params: moduleSubscriptionIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  moduleSubscriptionController.checkModuleSubscriptionEligibility
);

module.exports = router;
