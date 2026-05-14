/**
 * Lab sample routes
 *
 * @module modules/lab-sample/routes
 * @description Lab sample endpoints mounted at /api/v1/lab-samples
 */

const express = require('express');
const labSampleController = require('@controllers/lab-sample/lab-sample.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createLabSampleSchema,
  updateLabSampleSchema,
  labSampleIdParamsSchema,
  listLabSamplesQuerySchema,
} = require('@validations/lab-sample/lab-sample.schema');

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
  validateRequest({ query: listLabSamplesQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labSampleController.listLabSamples
);

router.get(
  '/:id',
  validateRequest({ params: labSampleIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labSampleController.getLabSampleById
);

router.post(
  '/',
  validateRequest({ body: createLabSampleSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labSampleController.createLabSample
);

router.put(
  '/:id',
  validateRequest({ params: labSampleIdParamsSchema, body: updateLabSampleSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labSampleController.updateLabSample
);

router.delete(
  '/:id',
  validateRequest({ params: labSampleIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labSampleController.deleteLabSample
);

module.exports = router;
