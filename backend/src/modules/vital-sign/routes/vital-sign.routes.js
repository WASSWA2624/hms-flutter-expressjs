/**
 * Vital sign routes
 */

const express = require('express');
const router = express.Router();
const vitalSignController = require('@controllers/vital-sign/vital-sign.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { requireClinicalDeletePrivilege } = require('@middlewares/clinical-guard.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createVitalSignSchema,
  updateVitalSignSchema,
  deleteVitalSignSchema,
  vitalSignIdParamsSchema,
  listVitalSignsQuerySchema,
} = require('@validations/vital-sign/vital-sign.schema');

router.get(
  '/',
  validateRequest({ query: listVitalSignsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  vitalSignController.listVitalSigns
);

router.get(
  '/:id',
  validateRequest({ params: vitalSignIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  vitalSignController.getVitalSignById
);

router.post(
  '/',
  validateRequest({ body: createVitalSignSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  vitalSignController.createVitalSign
);

router.put(
  '/:id',
  validateRequest({ params: vitalSignIdParamsSchema, body: updateVitalSignSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  vitalSignController.updateVitalSign
);

router.delete(
  '/:id',
  validateRequest({ params: vitalSignIdParamsSchema, body: deleteVitalSignSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  requireClinicalDeletePrivilege(),
  vitalSignController.deleteVitalSign
);

module.exports = router;

