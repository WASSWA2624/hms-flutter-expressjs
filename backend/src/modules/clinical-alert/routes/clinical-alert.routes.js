/**
 * Clinical Alert routes
 *
 * @module modules/clinical-alert/routes
 * @description Clinical alert endpoints mounted at /api/v1/clinical-alerts
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const clinicalAlertController = require('@controllers/clinical-alert/clinical-alert.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { requireClinicalDeletePrivilege } = require('@middlewares/clinical-guard.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createClinicalAlertSchema,
  updateClinicalAlertSchema,
  acknowledgeClinicalAlertSchema,
  resolveClinicalAlertSchema,
  clinicalAlertIdParamsSchema,
  listClinicalAlertsQuerySchema,
} = require('@validations/clinical-alert/clinical-alert.schema');

router.get(
  '/',
  validateRequest({ query: listClinicalAlertsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalAlertController.listClinicalAlerts
);

router.get(
  '/:id',
  validateRequest({ params: clinicalAlertIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalAlertController.getClinicalAlertById
);

router.post(
  '/',
  validateRequest({ body: createClinicalAlertSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalAlertController.createClinicalAlert
);

router.put(
  '/:id',
  validateRequest({ params: clinicalAlertIdParamsSchema, body: updateClinicalAlertSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalAlertController.updateClinicalAlert
);

router.delete(
  '/:id',
  validateRequest({ params: clinicalAlertIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  requireClinicalDeletePrivilege(),
  clinicalAlertController.deleteClinicalAlert
);

router.post(
  '/:id/acknowledge',
  validateRequest({ params: clinicalAlertIdParamsSchema, body: acknowledgeClinicalAlertSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalAlertController.acknowledgeClinicalAlert
);

router.post(
  '/:id/resolve',
  validateRequest({ params: clinicalAlertIdParamsSchema, body: resolveClinicalAlertSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalAlertController.resolveClinicalAlert
);

module.exports = router;
