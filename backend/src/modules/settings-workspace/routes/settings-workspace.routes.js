const express = require('express');
const { HttpError } = require('@lib/errors');
const { PERMISSIONS } = require('@config/permissions');
const { isFeatureEnabled } = require('@config/feature-flags');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const settingsWorkspaceController = require('@controllers/settings-workspace/settings-workspace.controller');
const {
  referenceDataQuerySchema,
  workspaceQuerySchema} = require('@validations/settings-workspace/settings-workspace.schema');

const router = express.Router();

// Match frontend settings workspace gates: admins + HR (permission or role pack).
const SETTINGS_WORKSPACE_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
  PERMISSIONS.HR_READ,
  PERMISSIONS.HR_WRITE,
];

const requireSettingsWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('settings_workspace_v1')) {
    return next(new HttpError('errors.settings.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireSettingsWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(SETTINGS_WORKSPACE_SCOPES, 'permission'),
  settingsWorkspaceController.getWorkspace
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(SETTINGS_WORKSPACE_SCOPES, 'permission'),
  settingsWorkspaceController.getReferenceData
);

module.exports = router;
