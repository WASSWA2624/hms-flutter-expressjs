/**
 * Diagnosis routes
 */

const express = require('express');
const router = express.Router();
const diagnosisController = require('@controllers/diagnosis/diagnosis.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createDiagnosisSchema,
  updateDiagnosisSchema,
  diagnosisIdParamsSchema,
  listDiagnosesQuerySchema,
} = require('@validations/diagnosis/diagnosis.schema');

router.get(
  '/',
  validateRequest({ query: listDiagnosesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  diagnosisController.listDiagnoses
);

router.get(
  '/:id',
  validateRequest({ params: diagnosisIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  diagnosisController.getDiagnosisById
);

router.post(
  '/',
  validateRequest({ body: createDiagnosisSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  diagnosisController.createDiagnosis
);

router.put(
  '/:id',
  validateRequest({ params: diagnosisIdParamsSchema, body: updateDiagnosisSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  diagnosisController.updateDiagnosis
);

// Soft-delete is a normal clinical chart correction (duplicate / wrong code).
// Doctors with clinical:write must be able to remove diagnoses; do not apply
// requireClinicalDeletePrivilege (admin-only cleanup) here.
router.delete(
  '/:id',
  validateRequest({ params: diagnosisIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  diagnosisController.deleteDiagnosis
);

module.exports = router;

