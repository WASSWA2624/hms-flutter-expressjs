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
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabSampleSchema,
  updateLabSampleSchema,
  labSampleIdParamsSchema,
  listLabSamplesQuerySchema} = require('@validations/lab-sample/lab-sample.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

router.get(
  '/',
  validateRequest({ query: listLabSamplesQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labSampleController.listLabSamples
);

router.get(
  '/:id',
  validateRequest({ params: labSampleIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labSampleController.getLabSampleById
);

router.post(
  '/',
  validateRequest({ body: createLabSampleSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labSampleController.createLabSample
);

router.put(
  '/:id',
  validateRequest({ params: labSampleIdParamsSchema, body: updateLabSampleSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labSampleController.updateLabSample
);

router.delete(
  '/:id',
  validateRequest({ params: labSampleIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labSampleController.deleteLabSample
);

module.exports = router;
