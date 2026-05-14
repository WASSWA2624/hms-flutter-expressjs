const express = require('express');
const router = express.Router();
const hrWorkspaceController = require('@controllers/hr-workspace/hr-workspace.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  workItemsQuerySchema,
  referenceDataQuerySchema,
  rosterIdentifierParamsSchema,
  shiftIdentifierParamsSchema,
  swapIdentifierParamsSchema,
  leaveIdentifierParamsSchema,
  payrollRunIdentifierParamsSchema,
  resolveLegacyParamsSchema,
  rosterGenerateSchema,
  rosterPublishSchema,
  shiftOverrideSchema,
  swapApproveSchema,
  swapRejectSchema,
  leaveApproveSchema,
  leaveRejectSchema,
  payrollPreviewQuerySchema,
  payrollProcessSchema,
} = require('@validations/hr-workspace/hr-workspace.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

const requireHrWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('hr_workspace_v1')) {
    return next(new HttpError('errors.hr.workspace_not_enabled', 404));
  }
  return next();
};

router.use(authenticate());
router.use(requireHrWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(HR_READ_SCOPES, 'permission'),
  hrWorkspaceController.getWorkspace
);

router.get(
  '/work-items',
  validateRequest({ query: workItemsQuerySchema }),
  authorize(HR_READ_SCOPES, 'permission'),
  hrWorkspaceController.getWorkItems
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(HR_READ_SCOPES, 'permission'),
  hrWorkspaceController.getReferenceData
);

router.get(
  '/rosters/:rosterIdentifier/workflow',
  validateRequest({ params: rosterIdentifierParamsSchema }),
  authorize(HR_READ_SCOPES, 'permission'),
  hrWorkspaceController.getRosterWorkflow
);

router.post(
  '/rosters/:rosterIdentifier/generate',
  validateRequest({ params: rosterIdentifierParamsSchema, body: rosterGenerateSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.generateRoster
);

router.post(
  '/rosters/:rosterIdentifier/publish',
  validateRequest({ params: rosterIdentifierParamsSchema, body: rosterPublishSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.publishRoster
);

router.post(
  '/shifts/:shiftIdentifier/override',
  validateRequest({ params: shiftIdentifierParamsSchema, body: shiftOverrideSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.overrideShift
);

router.post(
  '/swaps/:swapIdentifier/approve',
  validateRequest({ params: swapIdentifierParamsSchema, body: swapApproveSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.approveSwap
);

router.post(
  '/swaps/:swapIdentifier/reject',
  validateRequest({ params: swapIdentifierParamsSchema, body: swapRejectSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.rejectSwap
);

router.post(
  '/leaves/:leaveIdentifier/approve',
  validateRequest({ params: leaveIdentifierParamsSchema, body: leaveApproveSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.approveLeave
);

router.post(
  '/leaves/:leaveIdentifier/reject',
  validateRequest({ params: leaveIdentifierParamsSchema, body: leaveRejectSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.rejectLeave
);

router.get(
  '/payroll-runs/:payrollRunIdentifier/preview',
  validateRequest({ params: payrollRunIdentifierParamsSchema, query: payrollPreviewQuerySchema }),
  authorize(HR_READ_SCOPES, 'permission'),
  hrWorkspaceController.previewPayrollRun
);

router.post(
  '/payroll-runs/:payrollRunIdentifier/process',
  validateRequest({ params: payrollRunIdentifierParamsSchema, body: payrollProcessSchema }),
  authorize(HR_WRITE_SCOPES, 'permission'),
  hrWorkspaceController.processPayrollRun
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(HR_READ_SCOPES, 'permission'),
  hrWorkspaceController.resolveLegacyRoute
);

module.exports = router;
