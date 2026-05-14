/**
 * Payment routes
 *
 * @module modules/payment/routes
 * @description Payment endpoints mounted at /api/v1/payments
 */

const express = require('express');
const router = express.Router();
const paymentController = require('@controllers/payment/payment.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPaymentSchema,
  updatePaymentSchema,
  reconcilePaymentSchema,
  paymentIdParamsSchema,
  listPaymentsQuerySchema
} = require('@validations/payment/payment.schema');

/**
 * @description List payments with pagination and filters
 * @method GET
 * @route /api/v1/payments/
 * @authentication Required (JWT)
 */
router.get(
  '/',  validateRequest({ query: listPaymentsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  paymentController.listPayments
);

/**
 * @description Get payment by ID
 * @method GET
 * @route /api/v1/payments/:id
 * @authentication Required (JWT)
 */
router.get(
  '/:id',  validateRequest({ params: paymentIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  paymentController.getPaymentById
);

/**
 * @description Create payment
 * @method POST
 * @route /api/v1/payments/
 * @authentication Required (JWT)
 */
router.post(
  '/',  validateRequest({ body: createPaymentSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  paymentController.createPayment
);

/**
 * @description Update payment
 * @method PUT
 * @route /api/v1/payments/:id
 * @authentication Required (JWT)
 */
router.put(
  '/:id',  validateRequest({ params: paymentIdParamsSchema, body: updatePaymentSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  paymentController.updatePayment
);

/**
 * @description Delete payment (soft delete)
 * @method DELETE
 * @route /api/v1/payments/:id
 * @authentication Required (JWT)
 */
router.delete(
  '/:id',  validateRequest({ params: paymentIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  paymentController.deletePayment
);

router.post(
  '/:id/reconcile',
  validateRequest({ params: paymentIdParamsSchema, body: reconcilePaymentSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  paymentController.reconcilePayment
);

router.get(
  '/:id/channel-breakdown',
  validateRequest({ params: paymentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  paymentController.getPaymentChannelBreakdown
);

module.exports = router;
