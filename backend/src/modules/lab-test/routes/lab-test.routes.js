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
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabTestSchema,
  updateLabTestSchema,
  deleteLabTestSchema,
  labTestIdParamsSchema,
  listLabTestsQuerySchema} = require('@validations/lab-test/lab-test.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ, PERMISSIONS.CLINICAL_READ];

const LAB_CATALOG_WRITE_SCOPES = [
  PERMISSIONS.LAB_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN
];

router.get(
  '/',
  validateRequest({ query: listLabTestsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labTestController.listLabTests
);

router.get(
  '/:id',
  validateRequest({ params: labTestIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labTestController.getLabTestById
);

router.post(
  '/',
  validateRequest({ body: createLabTestSchema }),
  authenticate(),
  authorize(LAB_CATALOG_WRITE_SCOPES, 'permission'),
  labTestController.createLabTest
);

router.put(
  '/:id',
  validateRequest({ params: labTestIdParamsSchema, body: updateLabTestSchema }),
  authenticate(),
  authorize(LAB_CATALOG_WRITE_SCOPES, 'permission'),
  labTestController.updateLabTest
);

router.delete(
  '/:id',
  validateRequest({ params: labTestIdParamsSchema, body: deleteLabTestSchema }),
  authenticate(),
  authorize(LAB_CATALOG_WRITE_SCOPES, 'permission'),
  labTestController.deleteLabTest
);

module.exports = router;
