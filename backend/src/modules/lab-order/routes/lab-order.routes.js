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
const { ROLES } = require('@config/roles');
const {
  createLabOrderSchema,
  updateLabOrderSchema,
  labOrderIdParamsSchema,
  listLabOrdersQuerySchema,
} = require('@validations/lab-order/lab-order.schema');

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

const LAB_REQUEST_ROLES = LAB_READ_ROLES;

router.get(
  '/',
  validateRequest({ query: listLabOrdersQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labOrderController.listLabOrders
);

router.get(
  '/:id',
  validateRequest({ params: labOrderIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labOrderController.getLabOrderById
);

router.post(
  '/',
  validateRequest({ body: createLabOrderSchema }),
  authenticate(),
  authorize(LAB_REQUEST_ROLES, 'role'),
  labOrderController.createLabOrder
);

router.put(
  '/:id',
  validateRequest({ params: labOrderIdParamsSchema, body: updateLabOrderSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labOrderController.updateLabOrder
);

router.delete(
  '/:id',
  validateRequest({ params: labOrderIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labOrderController.deleteLabOrder
);

module.exports = router;
