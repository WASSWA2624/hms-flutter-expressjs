/**
 * Purchase request routes
 *
 * @module modules/purchase-request/routes
 * @description Express routes for purchase request endpoints.
 * Per module-creation.mdc: Routes define endpoints and apply middlewares.
 * Per api.mdc: All endpoints under /api/v1/purchase-requests
 */

const express = require('express');
const router = express.Router();

const purchaseRequestController = require('@controllers/purchase-request/purchase-request.controller');
const validate = require('@middlewares/validate.middleware');
const {
  createPurchaseRequestSchema,
  updatePurchaseRequestSchema,
  purchaseRequestIdParamsSchema,
  listPurchaseRequestsQuerySchema
} = require('@validations/purchase-request/purchase-request.schema');

/**
 * @route GET /api/v1/purchase-requests
 * @desc List purchase requests with pagination
 * @access Private
 */
router.get(
  '/',
  validate({ query: listPurchaseRequestsQuerySchema }),
  purchaseRequestController.listPurchaseRequests
);

/**
 * @route GET /api/v1/purchase-requests/:id
 * @desc Get purchase request by ID
 * @access Private
 */
router.get(
  '/:id',
  validate({ params: purchaseRequestIdParamsSchema }),
  purchaseRequestController.getPurchaseRequest
);

/**
 * @route POST /api/v1/purchase-requests
 * @desc Create new purchase request
 * @access Private
 */
router.post(
  '/',
  validate({ body: createPurchaseRequestSchema }),
  purchaseRequestController.createPurchaseRequest
);

/**
 * @route PUT /api/v1/purchase-requests/:id
 * @desc Update purchase request
 * @access Private
 */
router.put(
  '/:id',
  validate({ params: purchaseRequestIdParamsSchema, body: updatePurchaseRequestSchema }),
  purchaseRequestController.updatePurchaseRequest
);

/**
 * @route DELETE /api/v1/purchase-requests/:id
 * @desc Delete purchase request (soft delete)
 * @access Private
 */
router.delete(
  '/:id',
  validate({ params: purchaseRequestIdParamsSchema }),
  purchaseRequestController.deletePurchaseRequest
);

module.exports = router;
