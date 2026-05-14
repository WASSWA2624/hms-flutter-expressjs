/**
 * Subscription Plan routes
 *
 * @module modules/subscription-plan/routes
 * @description Route definitions for subscription plan endpoints.
 * Per module-creation.mdc: Mount endpoints as per dev-plan/P010_api_endpoints.mdc
 * Per api.mdc: All handlers wrapped with asyncHandler
 */

const express = require('express');
const router = express.Router();
const subscriptionPlanController = require('@controllers/subscription-plan/subscription-plan.controller');
const { asyncHandler } = require('@lib/async');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validate } = require('@middlewares/validate.middleware');
const {
  createSubscriptionPlanSchema,
  updateSubscriptionPlanSchema,
  subscriptionPlanIdParamsSchema,
  listSubscriptionPlansQuerySchema
} = require('@validations/subscription-plan/subscription-plan.schema');

/**
 * @description List subscription plans with pagination
 * @method GET
 * @route /api/v1/subscription-plans
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams None
 * @queryParams page, limit, sort_by, order, tenant_id, name, billing_cycle, search
 * @bodyParams None
 * @returns {Object} Paginated list of subscription plans
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validate({ query: listSubscriptionPlansQuerySchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionPlanController.listSubscriptionPlans)
);

/**
 * @description Get subscription plan by ID
 * @method GET
 * @route /api/v1/subscription-plans/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Subscription plan object
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 */
router.get(
  '/:id',
  validate({ params: subscriptionPlanIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionPlanController.getSubscriptionPlan)
);

/**
 * @description Get subscription plan entitlements
 * @method GET
 * @route /api/v1/subscription-plans/:id/entitlements
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Plan entitlements
 */
router.get(
  '/:id/entitlements',
  validate({ params: subscriptionPlanIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionPlanController.getSubscriptionPlanEntitlements)
);

/**
 * @description Get subscription plan add-on eligibility
 * @method GET
 * @route /api/v1/subscription-plans/:id/add-on-eligibility
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Add-on eligibility
 */
router.get(
  '/:id/add-on-eligibility',
  validate({ params: subscriptionPlanIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionPlanController.getSubscriptionPlanAddOnEligibility)
);

/**
 * @description Create new subscription plan
 * @method POST
 * @route /api/v1/subscription-plans
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams None
 * @queryParams None
 * @bodyParams tenant_id, name, price, billing_cycle
 * @returns {Object} Created subscription plan
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 409 Conflict
 */
router.post(
  '/',
  validate({ body: createSubscriptionPlanSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionPlanController.createSubscriptionPlan)
);

/**
 * @description Update subscription plan
 * @method PUT
 * @route /api/v1/subscription-plans/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams name, price, billing_cycle (all optional)
 * @returns {Object} Updated subscription plan
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 * @throws 409 Conflict
 */
router.put(
  '/:id',
  validate({ params: subscriptionPlanIdParamsSchema, body: updateSubscriptionPlanSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionPlanController.updateSubscriptionPlan)
);

/**
 * @description Delete subscription plan (soft delete)
 * @method DELETE
 * @route /api/v1/subscription-plans/:id
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
  validate({ params: subscriptionPlanIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_DELETE, 'permission'),
  asyncHandler(subscriptionPlanController.deleteSubscriptionPlan)
);

module.exports = router;
