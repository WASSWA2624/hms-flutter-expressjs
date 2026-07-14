/**
 * Interop routes
 */

const express = require('express');
const router = express.Router();
const interopController = require('@controllers/interop/interop.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  interopResourceParamsSchema,
  interopStudyIdParamsSchema,
  fhirImportSchema,
  hl7MessagesSchema,
  dicomStudyLinkSchema,
  interopMigrationImportSchema
} = require('@validations/interop/interop.schema');

router.get(
  '/fhir/export/:resource',
  validateRequest({ params: interopResourceParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.EVIDENCE_EXPORT, 'permission'),
  interopController.exportFhirResource
);

router.post(
  '/fhir/import/:resource',
  validateRequest({ params: interopResourceParamsSchema, body: fhirImportSchema }),
  interopController.importFhirResource
);

router.post(
  '/hl7/messages',
  validateRequest({ body: hl7MessagesSchema }),
  interopController.submitHl7Message
);

router.post(
  '/dicom/studies/:id/link',
  validateRequest({ params: interopStudyIdParamsSchema, body: dicomStudyLinkSchema }),
  interopController.linkDicomStudy
);

router.get(
  '/migrations/export',
  authenticate(),
  authorize(PERMISSIONS.EVIDENCE_EXPORT, 'permission'),
  interopController.exportMigrations
);

router.post(
  '/migrations/import',
  validateRequest({ body: interopMigrationImportSchema }),
  interopController.importMigrations
);

module.exports = router;
