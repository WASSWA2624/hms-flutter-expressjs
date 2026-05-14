const express = require('express');
const dashboardWorkspaceController = require('@controllers/dashboard-workspace/dashboard-workspace.controller');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { ROLES, ROLE_VALUES } = require('@config/roles');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  lookupsQuerySchema,
  workspaceQuerySchema,
} = require('@validations/dashboard-workspace/dashboard-workspace.schema');

const router = express.Router();
const DASHBOARD_WORKSPACE_ROLES = ROLE_VALUES.filter(
  (role) => role !== ROLES.PATIENT && role !== ROLES.OTHER
);

const requireDashboardWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('dashboard_workspace_v1')) {
    return next(new HttpError('errors.dashboard.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireDashboardWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(DASHBOARD_WORKSPACE_ROLES, 'role'),
  dashboardWorkspaceController.getWorkspace
);

router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(DASHBOARD_WORKSPACE_ROLES, 'role'),
  dashboardWorkspaceController.getLookups
);

module.exports = router;
