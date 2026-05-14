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
const { ROLES } = require('@config/roles');
const {
  createLabOrderItemSchema,
  updateLabOrderItemSchema,
  labOrderItemIdParamsSchema,
  listLabOrderItemsQuerySchema,
} = require('@validations/lab-order-item/lab-order-item.schema');

const router = express.Router();

const LAB_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const LAB_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.LAB_TECH,
];

router.get(
  '/',
  validateRequest({ query: listLabOrderItemsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labOrderItemController.listLabOrderItems
);

router.get(
  '/:id',
  validateRequest({ params: labOrderItemIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labOrderItemController.getLabOrderItemById
);

router.post(
  '/',
  validateRequest({ body: createLabOrderItemSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labOrderItemController.createLabOrderItem
);

router.put(
  '/:id',
  validateRequest({ params: labOrderItemIdParamsSchema, body: updateLabOrderItemSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labOrderItemController.updateLabOrderItem
);

router.delete(
  '/:id',
  validateRequest({ params: labOrderItemIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labOrderItemController.deleteLabOrderItem
);

module.exports = router;
