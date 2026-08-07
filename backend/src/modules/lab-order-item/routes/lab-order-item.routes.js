/**
 * Lab order item routes
 *
 * @module modules/lab-order-item/routes
 * @description Lab order item endpoints mounted at /api/v1/lab-order-items
 */

const express = require('express');
const labOrderItemController = require('@controllers/lab-order-item/lab-order-item.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabOrderItemSchema,
  updateLabOrderItemSchema,
  labOrderItemIdParamsSchema,
  listLabOrderItemsQuerySchema} = require('@validations/lab-order-item/lab-order-item.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ, PERMISSIONS.CLINICAL_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

router.get(
  '/',
  validateRequest({ query: listLabOrderItemsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labOrderItemController.listLabOrderItems
);

router.get(
  '/:id',
  validateRequest({ params: labOrderItemIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labOrderItemController.getLabOrderItemById
);

router.post(
  '/',
  validateRequest({ body: createLabOrderItemSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labOrderItemController.createLabOrderItem
);

router.put(
  '/:id',
  validateRequest({ params: labOrderItemIdParamsSchema, body: updateLabOrderItemSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labOrderItemController.updateLabOrderItem
);

router.delete(
  '/:id',
  validateRequest({ params: labOrderItemIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labOrderItemController.deleteLabOrderItem
);

module.exports = router;
