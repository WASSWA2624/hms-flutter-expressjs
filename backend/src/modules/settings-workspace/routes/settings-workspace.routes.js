const express = require('express');
const { HttpError } = require('@lib/errors');
const { ROLES } = require('@config/roles');
const { isFeatureEnabled } = require('@config/feature-flags');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const settingsWorkspaceController = require('@controllers/settings-workspace/settings-workspace.controller');
const {
  referenceDataQuerySchema,
  workspaceQuerySchema,
} = require('@validations/settings-workspace/settings-workspace.schema');

const router = express.Router();

const SETTINGS_WORKSPACE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
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
  authorize(SETTINGS_WORKSPACE_ROLES, 'role'),
  settingsWorkspaceController.getWorkspace
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(SETTINGS_WORKSPACE_ROLES, 'role'),
  settingsWorkspaceController.getReferenceData
);

module.exports = router;
