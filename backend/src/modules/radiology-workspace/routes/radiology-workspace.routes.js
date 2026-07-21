const express = require('express');
const { z } = require('zod');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const radiologyWorkspaceController = require('@controllers/radiology-workspace/radiology-workspace.controller');
const {
  getRadiologyWorkbenchQuerySchema,
  referenceDataQuerySchema,
  orderWorkflowParamsSchema,
  studyWorkflowParamsSchema,
  resultWorkflowParamsSchema,
  createRadiologyOrderSchema,
  updateRadiologyOrderRequestDetailsSchema,
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
  addendumRadiologyResultSchema} = require('@validations/radiology-workspace/radiology-workspace.schema');

const router = express.Router();

const RADIOLOGY_READ_SCOPES = [PERMISSIONS.RADIOLOGY_READ];

const RADIOLOGY_WRITE_SCOPES = [PERMISSIONS.RADIOLOGY_WRITE];

const resolveLegacyRouteParamsSchema = z.object({
  resource: z.enum([
    'radiology-orders',
    'radiology-results',
    'radiology-tests',
    'imaging-studies',
    'imaging-assets',
    'pacs-links']),
  id: uuidOrFriendlyIdentifierSchema});

router.get(
  '/workbench',
  validateRequest({ query: getRadiologyWorkbenchQuerySchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_SCOPES, 'permission'),
  radiologyWorkspaceController.getRadiologyWorkbench
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_SCOPES, 'permission'),
  radiologyWorkspaceController.getRadiologyReferenceData
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_SCOPES, 'permission'),
  radiologyWorkspaceController.resolveLegacyRoute
);

router.post(
  '/orders',
  validateRequest({ body: createRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.createRadiologyOrder
);

router.get(
  '/orders/:id/workflow',
  validateRequest({ params: orderWorkflowParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_SCOPES, 'permission'),
  radiologyWorkspaceController.getRadiologyOrderWorkflow
);

router.put(
  '/orders/:id/request-details',
  validateRequest({
    params: orderWorkflowParamsSchema,
    body: updateRadiologyOrderRequestDetailsSchema}),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.updateRadiologyOrderRequestDetails
);

router.post(
  '/orders/:id/assign',
  validateRequest({ params: orderWorkflowParamsSchema, body: assignRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.assignRadiologyOrder
);

router.post(
  '/orders/:id/start',
  validateRequest({ params: orderWorkflowParamsSchema, body: startRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.startRadiologyOrder
);

router.post(
  '/orders/:id/complete',
  validateRequest({ params: orderWorkflowParamsSchema, body: completeRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.completeRadiologyOrder
);

router.post(
  '/orders/:id/cancel',
  validateRequest({ params: orderWorkflowParamsSchema, body: cancelRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.cancelRadiologyOrder
);

router.post(
  '/orders/:id/studies',
  validateRequest({ params: orderWorkflowParamsSchema, body: createRadiologyStudySchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.createRadiologyStudy
);

router.post(
  '/studies/:id/assets/init-upload',
  validateRequest({ params: studyWorkflowParamsSchema, body: initUploadAssetSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.initStudyAssetUpload
);

router.post(
  '/studies/:id/assets/commit-upload',
  validateRequest({ params: studyWorkflowParamsSchema, body: commitUploadAssetSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.commitStudyAssetUpload
);

router.post(
  '/studies/:id/pacs-sync',
  validateRequest({ params: studyWorkflowParamsSchema, body: pacsSyncStudySchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.syncStudyToPacs
);

router.post(
  '/orders/:id/results/draft',
  validateRequest({ params: orderWorkflowParamsSchema, body: draftRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.draftRadiologyResult
);

router.post(
  '/results/:id/finalize',
  validateRequest({ params: resultWorkflowParamsSchema, body: finalizeRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.finalizeRadiologyResult
);

router.post(
  '/results/:id/request-finalization',
  validateRequest({ params: resultWorkflowParamsSchema, body: requestFinalizationRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.requestRadiologyResultFinalization
);

router.post(
  '/results/:id/attest-finalization',
  validateRequest({ params: resultWorkflowParamsSchema, body: attestFinalizationRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.attestRadiologyResultFinalization
);

router.post(
  '/results/:id/addendum',
  validateRequest({ params: resultWorkflowParamsSchema, body: addendumRadiologyResultSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_SCOPES, 'permission'),
  radiologyWorkspaceController.addendumRadiologyResult
);

module.exports = router;
