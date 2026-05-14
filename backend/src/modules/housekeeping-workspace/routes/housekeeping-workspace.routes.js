const express = require('express');
const router = express.Router();
const housekeepingWorkspaceController = require('@controllers/housekeeping-workspace/housekeeping-workspace.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  lookupsQuerySchema,
} = require('@validations/housekeeping-workspace/housekeeping-workspace.schema');

const HOUSEKEEPING_READ_SCOPES = [PERMISSIONS.OPERATIONS_READ];

const requireHousekeepingWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('housekeeping_workspace_v1')) {
    return next(new HttpError('errors.housekeeping.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireHousekeepingWorkspaceV1);

router.get(
  '/',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(HOUSEKEEPING_READ_SCOPES, 'permission'),
  housekeepingWorkspaceController.getWorkspace
);

router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(HOUSEKEEPING_READ_SCOPES, 'permission'),
  housekeepingWorkspaceController.getLookups
);

module.exports = router;
