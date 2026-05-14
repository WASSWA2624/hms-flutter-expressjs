/**
 * Billing Adjustment routes
 *
 * @module modules/billing-adjustment/routes
 * @description Billing Adjustment endpoints mounted at /api/v1/billing-adjustments
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const billingAdjustmentController = require('@controllers/billing-adjustment/billing-adjustment.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createBillingAdjustmentSchema,
  updateBillingAdjustmentSchema,
  billingAdjustmentIdParamsSchema,
  listBillingAdjustmentsQuerySchema
} = require('@validations/billing-adjustment/billing-adjustment.schema');

/**
 * @description List billing adjustments with pagination and filters
 * @method GET
 * @route /api/v1/billing-adjustments/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [invoice_id] - Filter by invoice ID (UUID)
 * @queryParams {string} [status] - Filter by status (DRAFT, ISSUED, PAID, PARTIAL, CANCELLED)
 * @queryParams {string} [search] - Search in reason field
 * @bodyParams None
 * @returns {Object} Paginated list of billing adjustments
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listBillingAdjustmentsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  billingAdjustmentController.listBillingAdjustments
);

/**
 * @description Get billing adjustment by ID
 * @method GET
 * @route /api/v1/billing-adjustments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Billing Adjustment ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Billing adjustment data
 * @throws 401 Unauthorized
 * @throws 404 Billing adjustment not found
 */
router.get(
  '/:id',  validateRequest({ params: billingAdjustmentIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  billingAdjustmentController.getBillingAdjustmentById
);

/**
 * @description Create new billing adjustment
 * @method POST
 * @route /api/v1/billing-adjustments/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} invoice_id - Invoice ID (required, UUID)
 * @bodyParams {number} amount - Adjustment amount (required, finite number)
 * @bodyParams {string} status - Adjustment status (required, DRAFT/ISSUED/PAID/PARTIAL/CANCELLED)
 * @bodyParams {string} [reason] - Adjustment reason (optional, max 255 chars)
 * @bodyParams {string} [adjusted_at] - Adjustment timestamp (optional, ISO 8601 datetime)
 * @returns {Object} Created billing adjustment
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createBillingAdjustmentSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  billingAdjustmentController.createBillingAdjustment
);

/**
 * @description Update billing adjustment
 * @method PUT
 * @route /api/v1/billing-adjustments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Billing Adjustment ID (UUID)
 * @queryParams None
 * @bodyParams {number} [amount] - Adjustment amount (finite number)
 * @bodyParams {string} [status] - Adjustment status (DRAFT/ISSUED/PAID/PARTIAL/CANCELLED)
 * @bodyParams {string} [reason] - Adjustment reason (max 255 chars)
 * @bodyParams {string} [adjusted_at] - Adjustment timestamp (ISO 8601 datetime)
 * @returns {Object} Updated billing adjustment
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Billing adjustment not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: billingAdjustmentIdParamsSchema, body: updateBillingAdjustmentSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  billingAdjustmentController.updateBillingAdjustment
);

/**
 * @description Delete billing adjustment (soft delete)
 * @method DELETE
 * @route /api/v1/billing-adjustments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Billing Adjustment ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Billing adjustment not found
 */
router.delete(
  '/:id',  validateRequest({ params: billingAdjustmentIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  billingAdjustmentController.deleteBillingAdjustment
);

module.exports = router;
