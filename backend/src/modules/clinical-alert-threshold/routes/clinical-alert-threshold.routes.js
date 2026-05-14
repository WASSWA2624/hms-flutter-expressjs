/**
 * Clinical alert threshold routes
 */

const express = require('express');
const router = express.Router();
const clinicalAlertThresholdController = require('@controllers/clinical-alert-threshold/clinical-alert-threshold.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  listClinicalAlertThresholdsQuerySchema,
  updateClinicalAlertThresholdsSchema,
} = require('@validations/clinical-alert-threshold/clinical-alert-threshold.schema');

router.get(
  '/',
  validateRequest({ query: listClinicalAlertThresholdsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalAlertThresholdController.listClinicalAlertThresholds
);

router.put(
  '/',
  validateRequest({ body: updateClinicalAlertThresholdsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalAlertThresholdController.updateClinicalAlertThresholds
);

module.exports = router;

