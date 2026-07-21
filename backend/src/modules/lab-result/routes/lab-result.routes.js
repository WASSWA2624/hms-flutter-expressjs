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
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabResultSchema,
  updateLabResultSchema,
  releaseLabResultSchema,
  labResultIdParamsSchema,
  listLabResultsQuerySchema} = require('@validations/lab-result/lab-result.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

router.get(
  '/',
  validateRequest({ query: listLabResultsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labResultController.listLabResults
);

router.get(
  '/:id',
  validateRequest({ params: labResultIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labResultController.getLabResultById
);

router.post(
  '/',
  validateRequest({ body: createLabResultSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labResultController.createLabResult
);

router.put(
  '/:id',
  validateRequest({ params: labResultIdParamsSchema, body: updateLabResultSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labResultController.updateLabResult
);

router.delete(
  '/:id',
  validateRequest({ params: labResultIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labResultController.deleteLabResult
);

router.post(
  '/:id/release',
  validateRequest({ params: labResultIdParamsSchema, body: releaseLabResultSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labResultController.releaseLabResult
);

module.exports = router;
