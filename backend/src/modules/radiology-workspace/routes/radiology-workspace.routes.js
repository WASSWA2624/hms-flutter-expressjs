const express = require('express');
const { z } = require('zod');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const radiologyWorkspaceController = require('@controllers/radiology-workspace/radiology-workspace.controller');
const {
  getRadiologyWorkbenchQuerySchema,
  referenceDataQuerySchema,
  orderWorkflowParamsSchema,
  studyWorkflowParamsSchema,
  resultWorkflowParamsSchema,
  createRadiologyOrderSchema,
  assignRadiologyOrderSchema,
  startRadiologyOrderSchema,
  completeRadiologyOrderSchema,
  cancelRadiologyOrderSchema,
  createRadiologyStudySchema,
  initUploadAssetSchema,
  commitUploadAssetSchema,
  pacsSyncStudySchema,
  draftRadiologyResultSchema,
  finalizeRadiologyResultSchema,
  requestFinalizationRadiologyResultSchema,
  attestFinalizationRadiologyResultSchema,
  addendumRadiologyResultSchema,
} = require('@validations/radiology-workspace/radiology-workspace.schema');

const router = express.Router();

const RADIOLOGY_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
  ROLES.RADIOLOGY_TECH,
];

const resolveLegacyRouteParamsSchema = z.object({
  resource: z.enum([
    'radiology-orders',
    'radiology-results',
    'radiology-tests',
    'imaging-studies',
    'imaging-assets',
    'pacs-links',
  ]),
  id: uuidOrFriendlyIdentifierSchema,
});

router.get(
  '/workbench',
  validateRequest({ query: getRadiologyWorkbenchQuerySchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.getRadiologyWorkbench
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.getRadiologyReferenceData
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.resolveLegacyRoute
);

router.post(
  '/orders',
  validateRequest({ body: createRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.createRadiologyOrder
);

router.get(
  '/orders/:id/workflow',
  validateRequest({ params: orderWorkflowParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.getRadiologyOrderWorkflow
);

router.post(
  '/orders/:id/assign',
  validateRequest({ params: orderWorkflowParamsSchema, body: assignRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.assignRadiologyOrder
);

router.post(
  '/orders/:id/start',
  validateRequest({ params: orderWorkflowParamsSchema, body: startRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.startRadiologyOrder
);

router.post(
  '/orders/:id/complete',
  validateRequest({ params: orderWorkflowParamsSchema, body: completeRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.completeRadiologyOrder
);

router.post(
  '/orders/:id/cancel',
  validateRequest({ params: orderWorkflowParamsSchema, body: cancelRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.cancelRadiologyOrder
);

router.post(
  '/orders/:id/studies',
  validateRequest({ params: orderWorkflowParamsSchema, body: createRadiologyStudySchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.createRadiologyStudy
);

router.post(
  '/studies/:id/assets/init-upload',
  validateRequest({ params: studyWorkflowParamsSchema, body: initUploadAssetSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.initStudyAssetUpload
);

router.post(
  '/studies/:id/assets/commit-upload',
  validateRequest({ params: studyWorkflowParamsSchema, body: commitUploadAssetSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.commitStudyAssetUpload
);

router.post(
  '/studies/:id/pacs-sync',
  validateRequest({ params: studyWorkflowParamsSchema, body: pacsSyncStudySchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.syncStudyToPacs
);

router.post(
  '/orders/:id/results/draft',
  validateRequest({ params: orderWorkflowParamsSchema, body: draftRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.draftRadiologyResult
);

router.post(
  '/results/:id/finalize',
  validateRequest({ params: resultWorkflowParamsSchema, body: finalizeRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.finalizeRadiologyResult
);

router.post(
  '/results/:id/request-finalization',
  validateRequest({ params: resultWorkflowParamsSchema, body: requestFinalizationRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.requestRadiologyResultFinalization
);

router.post(
  '/results/:id/attest-finalization',
  validateRequest({ params: resultWorkflowParamsSchema, body: attestFinalizationRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.attestRadiologyResultFinalization
);

router.post(
  '/results/:id/addendum',
  validateRequest({ params: resultWorkflowParamsSchema, body: addendumRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_ALLOWED_ROLES, 'role'),
  radiologyWorkspaceController.addendumRadiologyResult
);

module.exports = router;
