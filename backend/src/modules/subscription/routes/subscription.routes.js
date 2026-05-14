/**
 * Subscription routes
 *
 * @module modules/subscription/routes
 * @description Route definitions for subscription endpoints.
 * Per module-creation.mdc: Mount endpoints as per dev-plan/P010_api_endpoints.mdc
 * Per api.mdc: All handlers wrapped with asyncHandler
 */

const express = require('express');
const router = express.Router();
const subscriptionController = require('@controllers/subscription/subscription.controller');
const { asyncHandler } = require('@lib/async');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validate } = require('@middlewares/validate.middleware');
const {
  createSubscriptionSchema,
  updateSubscriptionSchema,
  changeSubscriptionPlanSchema,
  renewSubscriptionSchema,
  subscriptionIdParamsSchema,
  listSubscriptionsQuerySchema
} = require('@validations/subscription/subscription.schema');

/**
 * @description List subscriptions with pagination
 * @method GET
 * @route /api/v1/subscriptions
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams None
 * @queryParams page, limit, sort_by, order, tenant_id, plan_id, status, search
 * @bodyParams None
 * @returns {Object} Paginated list of subscriptions
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validate({ query: listSubscriptionsQuerySchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionController.listSubscriptions)
);

/**
 * @description Get subscription by ID
 * @method GET
 * @route /api/v1/subscriptions/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Subscription object
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 */
router.get(
  '/:id',
  validate({ params: subscriptionIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionController.getSubscription)
);

router.post(
  '/:id/upgrade',
  validate({ params: subscriptionIdParamsSchema, body: changeSubscriptionPlanSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionController.upgradeSubscription)
);

router.post(
  '/:id/downgrade',
  validate({ params: subscriptionIdParamsSchema, body: changeSubscriptionPlanSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionController.downgradeSubscription)
);

router.post(
  '/:id/renew',
  validate({ params: subscriptionIdParamsSchema, body: renewSubscriptionSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionController.renewSubscription)
);

router.get(
  '/:id/proration-preview',
  validate({ params: subscriptionIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionController.getSubscriptionProrationPreview)
);

router.get(
  '/:id/usage-summary',
  validate({ params: subscriptionIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionController.getSubscriptionUsageSummary)
);

router.get(
  '/:id/fit-check',
  validate({ params: subscriptionIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionController.getSubscriptionFitCheck)
);

router.get(
  '/:id/upgrade-recommendation',
  validate({ params: subscriptionIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionController.getSubscriptionUpgradeRecommendation)
);

/**
 * @description Create new subscription
 * @method POST
 * @route /api/v1/subscriptions
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams None
 * @queryParams None
 * @bodyParams tenant_id, plan_id, status, start_date, end_date
 * @returns {Object} Created subscription
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 409 Conflict
 */
router.post(
  '/',
  validate({ body: createSubscriptionSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionController.createSubscription)
);

/**
 * @description Update subscription
 * @method PUT
 * @route /api/v1/subscriptions/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams plan_id, status, start_date, end_date (all optional)
 * @returns {Object} Updated subscription
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 * @throws 409 Conflict
 */
router.put(
  '/:id',
  validate({ params: subscriptionIdParamsSchema, body: updateSubscriptionSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionController.updateSubscription)
);

/**
 * @description Delete subscription (soft delete)
 * @method DELETE
 * @route /api/v1/subscriptions/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 */
router.delete(
  '/:id',
  validate({ params: subscriptionIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_DELETE, 'permission'),
  asyncHandler(subscriptionController.deleteSubscription)
);

module.exports = router;
