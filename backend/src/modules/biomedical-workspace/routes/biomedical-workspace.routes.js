const express = require('express');
const router = express.Router();
const biomedicalWorkspaceController = require('@controllers/biomedical-workspace/biomedical-workspace.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  lookupsQuerySchema,
  faultReportSchema,
} = require('@validations/biomedical-workspace/biomedical-workspace.schema');

const BIOMED_READ_SCOPES = [PERMISSIONS.BIOMED_READ, PERMISSIONS.OPERATIONS_READ];
const BIOMED_WRITE_SCOPES = [PERMISSIONS.BIOMED_WRITE, PERMISSIONS.OPERATIONS_WRITE, PERMISSIONS.CLINICAL_WRITE];
const BIOMED_LOOKUP_SCOPES = Array.from(
  new Set([...BIOMED_READ_SCOPES, ...BIOMED_WRITE_SCOPES])
);

const requireBiomedicalWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('biomedical_workspace_v1')) {
    return next(new HttpError('errors.biomedical.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireBiomedicalWorkspaceV1);

router.get(
  '/',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(BIOMED_READ_SCOPES, 'permission'),
  biomedicalWorkspaceController.getWorkspace
);

router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(BIOMED_LOOKUP_SCOPES, 'permission'),
  biomedicalWorkspaceController.getLookups
);

router.post(
  '/fault-reports',
  validateRequest({ body: faultReportSchema }),
  authorize(BIOMED_WRITE_SCOPES, 'permission'),
  biomedicalWorkspaceController.createFaultReport
);

module.exports = router;
