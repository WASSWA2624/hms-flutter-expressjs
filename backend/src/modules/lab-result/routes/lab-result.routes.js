/**
 * Lab result routes
 *
 * @module modules/lab-result/routes
 * @description Lab result endpoints mounted at /api/v1/lab-results
 */

const express = require('express');
const labResultController = require('@controllers/lab-result/lab-result.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createLabResultSchema,
  updateLabResultSchema,
  releaseLabResultSchema,
  labResultIdParamsSchema,
  listLabResultsQuerySchema,
} = require('@validations/lab-result/lab-result.schema');

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
  validateRequest({ query: listLabResultsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labResultController.listLabResults
);

router.get(
  '/:id',
  validateRequest({ params: labResultIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labResultController.getLabResultById
);

router.post(
  '/',
  validateRequest({ body: createLabResultSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labResultController.createLabResult
);

router.put(
  '/:id',
  validateRequest({ params: labResultIdParamsSchema, body: updateLabResultSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labResultController.updateLabResult
);

router.delete(
  '/:id',
  validateRequest({ params: labResultIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labResultController.deleteLabResult
);

router.post(
  '/:id/release',
  validateRequest({ params: labResultIdParamsSchema, body: releaseLabResultSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labResultController.releaseLabResult
);

module.exports = router;
