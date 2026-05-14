/**
 * Lab test routes
 *
 * @module modules/lab-test/routes
 * @description Lab test endpoints mounted at /api/v1/lab-tests
 */

const express = require('express');
const labTestController = require('@controllers/lab-test/lab-test.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createLabTestSchema,
  updateLabTestSchema,
  labTestIdParamsSchema,
  listLabTestsQuerySchema,
} = require('@validations/lab-test/lab-test.schema');

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
  validateRequest({ query: listLabTestsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labTestController.listLabTests
);

router.get(
  '/:id',
  validateRequest({ params: labTestIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labTestController.getLabTestById
);

router.post(
  '/',
  validateRequest({ body: createLabTestSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labTestController.createLabTest
);

router.put(
  '/:id',
  validateRequest({ params: labTestIdParamsSchema, body: updateLabTestSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labTestController.updateLabTest
);

router.delete(
  '/:id',
  validateRequest({ params: labTestIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labTestController.deleteLabTest
);

module.exports = router;
