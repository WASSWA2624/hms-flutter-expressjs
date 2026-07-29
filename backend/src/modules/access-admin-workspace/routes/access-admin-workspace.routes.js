const express = require('express');
const { HttpError } = require('@lib/errors');
const { PERMISSIONS } = require('@config/permissions');
const { isFeatureEnabled } = require('@config/feature-flags');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const accessAdminWorkspaceController = require('@controllers/access-admin-workspace/access-admin-workspace.controller');
const {
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  restoreAccessDefaultsSchema,
  userIdentifierParamsSchema,
  workspaceQuerySchema,
} = require('@validations/access-admin-workspace/access-admin-workspace.schema');

const router = express.Router();

// Permission-gated (not role-name gated) so custom roles holding the same
// grants as predefined admin roles get identical access.
const ACCESS_ADMIN_SCOPES = [
  PERMISSIONS.ACCESS_ADMIN_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

const PLATFORM_ADMIN_SCOPES = [PERMISSIONS.SYSTEM_ADMIN];

const requireAccessAdminWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('access_admin_workspace_v1')) {
    return next(new HttpError('errors.access_admin.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireAccessAdminWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.getWorkspace
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.getReferenceData
);

router.get(
  '/users/:userIdentifier/detail',
  validateRequest({ params: userIdentifierParamsSchema, query: referenceDataQuerySchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.getUserDetail
);

router.post(
  '/demo-users/:userIdentifier/reset-password',
  validateRequest({ params: userIdentifierParamsSchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.resetDemoUserPassword
);

router.post(
  '/registrations/:userIdentifier/activate',
  validateRequest({ params: userIdentifierParamsSchema }),
  authorize(SUPER_ADMIN_ONLY, 'role'),
  accessAdminWorkspaceController.activateRegistration
);

router.post(
  '/registrations/:userIdentifier/reject',
  validateRequest({ params: userIdentifierParamsSchema }),
  authorize(SUPER_ADMIN_ONLY, 'role'),
  accessAdminWorkspaceController.rejectRegistration
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.resolveLegacyRoute
);

router.post(
  '/restore-defaults',
  validateRequest({ body: restoreAccessDefaultsSchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.restoreAccessDefaults
);

module.exports = router;
