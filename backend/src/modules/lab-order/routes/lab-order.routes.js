/**
 * Lab order routes
 *
 * @module modules/lab-order/routes
 * @description Lab order endpoints mounted at /api/v1/lab-orders
 */

const express = require('express');
const labOrderController = require('@controllers/lab-order/lab-order.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabOrderSchema,
  updateLabOrderSchema,
  deleteLabOrderSchema,
  labOrderIdParamsSchema,
  listLabOrdersQuerySchema} = require('@validations/lab-order/lab-order.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ, PERMISSIONS.CLINICAL_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

// Doctors order labs from Clinical without a top-level Laboratory workspace.
const LAB_REQUEST_SCOPES = [PERMISSIONS.LAB_READ, PERMISSIONS.CLINICAL_WRITE];

router.get(
  '/',
  validateRequest({ query: listLabOrdersQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labOrderController.listLabOrders
);

router.get(
  '/:id',
  validateRequest({ params: labOrderIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labOrderController.getLabOrderById
);

router.post(
  '/',
  validateRequest({ body: createLabOrderSchema }),
  authenticate(),
  authorize(LAB_REQUEST_SCOPES, 'permission'),
  labOrderController.createLabOrder
);

router.put(
  '/:id',
  validateRequest({ params: labOrderIdParamsSchema, body: updateLabOrderSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labOrderController.updateLabOrder
);

router.delete(
  '/:id',
  validateRequest({ params: labOrderIdParamsSchema, body: deleteLabOrderSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labOrderController.deleteLabOrder
);

module.exports = router;
