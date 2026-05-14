/**
 * Refund routes
 *
 * @module modules/refund/routes
 * @description Refund endpoints mounted at /api/v1/refunds
 */

const express = require('express');
const router = express.Router();
const refundController = require('@controllers/refund/refund.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createRefundSchema,
  updateRefundSchema,
  refundIdParamsSchema,
  listRefundsQuerySchema
} = require('@validations/refund/refund.schema');

/**
 * @description List refunds with pagination and filters
 * @method GET
 * @route /api/v1/refunds/
 * @authentication Required (JWT)
 */
router.get(
  '/',  validateRequest({ query: listRefundsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  refundController.listRefunds
);

/**
 * @description Get refund by ID
 * @method GET
 * @route /api/v1/refunds/:id
 * @authentication Required (JWT)
 */
router.get(
  '/:id',  validateRequest({ params: refundIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  refundController.getRefundById
);

/**
 * @description Create refund
 * @method POST
 * @route /api/v1/refunds/
 * @authentication Required (JWT)
 */
router.post(
  '/',  validateRequest({ body: createRefundSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  refundController.createRefund
);

/**
 * @description Update refund
 * @method PUT
 * @route /api/v1/refunds/:id
 * @authentication Required (JWT)
 */
router.put(
  '/:id',  validateRequest({ params: refundIdParamsSchema, body: updateRefundSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  refundController.updateRefund
);

/**
 * @description Delete refund (soft delete)
 * @method DELETE
 * @route /api/v1/refunds/:id
 * @authentication Required (JWT)
 */
router.delete(
  '/:id',  validateRequest({ params: refundIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  refundController.deleteRefund
);

module.exports = router;
