/**
 * Subscription Invoice routes
 *
 * @module modules/subscription-invoice/routes
 * @description Route definitions for subscription invoice endpoints.
 * Per module-creation.mdc: Mount endpoints as per dev-plan/P010_api_endpoints.mdc
 * Per api.mdc: All handlers wrapped with asyncHandler
 */

const express = require('express');
const router = express.Router();
const subscriptionInvoiceController = require('@controllers/subscription-invoice/subscription-invoice.controller');
const { asyncHandler } = require('@lib/async');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validate } = require('@middlewares/validate.middleware');
const {
  createSubscriptionInvoiceSchema,
  updateSubscriptionInvoiceSchema,
  collectSubscriptionInvoiceSchema,
  retrySubscriptionInvoiceSchema,
  subscriptionInvoiceIdParamsSchema,
  listSubscriptionInvoicesQuerySchema
} = require('@validations/subscription-invoice/subscription-invoice.schema');

/**
 * @description List subscription invoices with pagination
 * @method GET
 * @route /api/v1/subscription-invoices
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams None
 * @queryParams page, limit, sort_by, order, subscription_id, invoice_id
 * @bodyParams None
 * @returns {Object} Paginated list of subscription invoices
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validate({ query: listSubscriptionInvoicesQuerySchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionInvoiceController.listSubscriptionInvoices)
);

/**
 * @description Get subscription invoice by ID
 * @method GET
 * @route /api/v1/subscription-invoices/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Subscription invoice object
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 */
router.get(
  '/:id',
  validate({ params: subscriptionInvoiceIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  asyncHandler(subscriptionInvoiceController.getSubscriptionInvoice)
);

router.post(
  '/:id/collect',
  validate({ params: subscriptionInvoiceIdParamsSchema, body: collectSubscriptionInvoiceSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionInvoiceController.collectSubscriptionInvoice)
);

router.post(
  '/:id/retry',
  validate({ params: subscriptionInvoiceIdParamsSchema, body: retrySubscriptionInvoiceSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionInvoiceController.retrySubscriptionInvoice)
);

/**
 * @description Create new subscription invoice
 * @method POST
 * @route /api/v1/subscription-invoices
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams None
 * @queryParams None
 * @bodyParams subscription_id, invoice_id
 * @returns {Object} Created subscription invoice
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 409 Conflict
 */
router.post(
  '/',
  validate({ body: createSubscriptionInvoiceSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionInvoiceController.createSubscriptionInvoice)
);

/**
 * @description Update subscription invoice
 * @method PUT
 * @route /api/v1/subscription-invoices/:id
 * @authentication Required (JWT)
 * @permissions TBD
 * @urlParams id (UUID)
 * @queryParams None
 * @bodyParams subscription_id, invoice_id (all optional)
 * @returns {Object} Updated subscription invoice
 * @throws 400 Bad request
 * @throws 401 Unauthorized
 * @throws 404 Not found
 * @throws 409 Conflict
 */
router.put(
  '/:id',
  validate({ params: subscriptionInvoiceIdParamsSchema, body: updateSubscriptionInvoiceSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  asyncHandler(subscriptionInvoiceController.updateSubscriptionInvoice)
);

/**
 * @description Delete subscription invoice (soft delete)
 * @method DELETE
 * @route /api/v1/subscription-invoices/:id
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
  validate({ params: subscriptionInvoiceIdParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_DELETE, 'permission'),
  asyncHandler(subscriptionInvoiceController.deleteSubscriptionInvoice)
);

module.exports = router;
