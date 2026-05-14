/**
 * Webhook subscription routes
 *
 * @module modules/webhook-subscription/routes
 * @description Express router for webhook subscription endpoints.
 * Per module-creation.mdc: Routes define endpoints and apply middleware.
 * Per api.mdc: All endpoints follow RESTful conventions.
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const { validate } = require('@middlewares/validate.middleware');
const webhookSubscriptionController = require('@controllers/webhook-subscription/webhook-subscription.controller');
const {
  createWebhookSubscriptionSchema,
  updateWebhookSubscriptionSchema,
  replayWebhookSubscriptionSchema,
  webhookSubscriptionIdParamsSchema,
  listWebhookSubscriptionsQuerySchema
} = require('@validations/webhook-subscription/webhook-subscription.schema');

/**
 * @description List webhook subscriptions with pagination
 * @method GET
 * @route /api/v1/webhook-subscriptions
 * @authentication Required (JWT)
 * @permissions Read webhook subscriptions
 * @urlParams None
 * @queryParams {number} page - Page number (default: 1)
 * @queryParams {number} limit - Items per page (default: 20)
 * @queryParams {string} sort_by - Sort field (default: created_at)
 * @queryParams {string} order - Sort order: asc/desc (default: desc)
 * @queryParams {string} tenant_id - Filter by tenant ID
 * @queryParams {string} integration_id - Filter by integration ID
 * @queryParams {string} event - Filter by event (partial match)
 * @queryParams {string} is_active - Filter by active status (true/false)
 * @queryParams {string} search - Search across fields
 * @bodyParams None
 * @returns {Object} Paginated list of webhook subscriptions
 * @throws 400 Invalid query parameters
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validate({ query: listWebhookSubscriptionsQuerySchema }),
  asyncHandler(webhookSubscriptionController.listWebhookSubscriptions)
);

/**
 * @description Get webhook subscription by ID
 * @method GET
 * @route /api/v1/webhook-subscriptions/:id
 * @authentication Required (JWT)
 * @permissions Read webhook subscriptions
 * @urlParams {string} id - Webhook subscription ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Webhook subscription object
 * @throws 400 Invalid ID format
 * @throws 401 Unauthorized
 * @throws 404 Webhook subscription not found
 */
router.get(
  '/:id',
  validate({ params: webhookSubscriptionIdParamsSchema }),
  asyncHandler(webhookSubscriptionController.getWebhookSubscription)
);

router.post(
  '/:id/replay',
  validate({ params: webhookSubscriptionIdParamsSchema, body: replayWebhookSubscriptionSchema }),
  asyncHandler(webhookSubscriptionController.replayWebhookSubscription)
);

/**
 * @description Create new webhook subscription
 * @method POST
 * @route /api/v1/webhook-subscriptions
 * @authentication Required (JWT)
 * @permissions Create webhook subscriptions
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (UUID)
 * @bodyParams {string} integration_id - Integration ID (UUID, optional)
 * @bodyParams {string} event - Event name (max 120 chars)
 * @bodyParams {string} target_url - Target URL (max 255 chars)
 * @bodyParams {boolean} is_active - Is active (default: true)
 * @returns {Object} Created webhook subscription
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validate({ body: createWebhookSubscriptionSchema }),
  asyncHandler(webhookSubscriptionController.createWebhookSubscription)
);

/**
 * @description Update webhook subscription
 * @method PUT
 * @route /api/v1/webhook-subscriptions/:id
 * @authentication Required (JWT)
 * @permissions Update webhook subscriptions
 * @urlParams {string} id - Webhook subscription ID (UUID)
 * @queryParams None
 * @bodyParams {string} integration_id - Integration ID (optional)
 * @bodyParams {string} event - Event name (optional)
 * @bodyParams {string} target_url - Target URL (optional)
 * @bodyParams {boolean} is_active - Is active (optional)
 * @returns {Object} Updated webhook subscription
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 * @throws 404 Webhook subscription not found
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validate({ params: webhookSubscriptionIdParamsSchema, body: updateWebhookSubscriptionSchema }),
  asyncHandler(webhookSubscriptionController.updateWebhookSubscription)
);

/**
 * @description Delete webhook subscription (soft delete)
 * @method DELETE
 * @route /api/v1/webhook-subscriptions/:id
 * @authentication Required (JWT)
 * @permissions Delete webhook subscriptions
 * @urlParams {string} id - Webhook subscription ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 400 Invalid ID format
 * @throws 401 Unauthorized
 * @throws 404 Webhook subscription not found
 */
router.delete(
  '/:id',
  validate({ params: webhookSubscriptionIdParamsSchema }),
  asyncHandler(webhookSubscriptionController.deleteWebhookSubscription)
);

module.exports = router;
