const express = require('express');
const dashboardWorkspaceController = require('@controllers/dashboard-workspace/dashboard-workspace.controller');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  lookupsQuerySchema,
  workspaceQuerySchema,
} = require('@validations/dashboard-workspace/dashboard-workspace.schema');

const router = express.Router();

// Custom roles are not in ROLE_VALUES; authorize by staff permissions instead.
const DASHBOARD_WORKSPACE_SCOPES = [
  PERMISSIONS.PROFILE_READ,
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.LAB_READ,
  PERMISSIONS.RADIOLOGY_READ,
  PERMISSIONS.PHARMACY_READ,
  PERMISSIONS.BILLING_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.HR_READ,
  PERMISSIONS.REPORTS_READ,
  PERMISSIONS.COMMUNICATIONS_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

const DASHBOARD_LOOKUP_SCOPES = DASHBOARD_WORKSPACE_SCOPES;

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
  authorize(DASHBOARD_WORKSPACE_SCOPES, 'permission'),
  dashboardWorkspaceController.getWorkspace
);

router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(DASHBOARD_LOOKUP_SCOPES, 'permission'),
  dashboardWorkspaceController.getLookups
);

module.exports = router;
