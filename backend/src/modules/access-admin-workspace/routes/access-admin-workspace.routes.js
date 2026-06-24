const express = require('express');
const { HttpError } = require('@lib/errors');
const { ROLES } = require('@config/roles');
const { isFeatureEnabled } = require('@config/feature-flags');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const accessAdminWorkspaceController = require('@controllers/access-admin-workspace/access-admin-workspace.controller');
const {
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  userIdentifierParamsSchema,
  workspaceQuerySchema,
} = require('@validations/access-admin-workspace/access-admin-workspace.schema');

const router = express.Router();

const ACCESS_ADMIN_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.HR,
  ROLES.OPERATIONS,
];

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

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(ACCESS_ADMIN_ROLES, 'role'),
  accessAdminWorkspaceController.resolveLegacyRoute
);

module.exports = router;
