const express = require('express');
const reportsWorkspaceController = require('@controllers/reports-workspace/reports-workspace.controller');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  lookupsQuerySchema,
  workspaceQuerySchema,
} = require('@validations/reports-workspace/reports-workspace.schema');

const router = express.Router();

const requireReportsWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('reports_workspace_v1')) {
    return next(new HttpError('errors.reports.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireReportsWorkspaceV1);

router.get(
  '/',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportsWorkspaceController.getWorkspace
);

router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportsWorkspaceController.getLookups
);

module.exports = router;
