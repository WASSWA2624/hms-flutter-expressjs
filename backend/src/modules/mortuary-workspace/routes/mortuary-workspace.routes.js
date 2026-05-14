const express = require('express');
const router = express.Router();
const mortuaryWorkspaceController = require('@controllers/mortuary-workspace/mortuary-workspace.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  lookupsQuerySchema,
} = require('@validations/mortuary-workspace/mortuary-workspace.schema');

const MORTUARY_READ_SCOPES = [
  PERMISSIONS.MORTUARY_READ,
  PERMISSIONS.MORTUARY_WRITE,
  PERMISSIONS.MORTUARY_APPROVE,
  PERMISSIONS.MORTUARY_RELEASE,
  PERMISSIONS.MORTUARY_AUDIT,
];

/**
 * Guard Mortuary routes behind the module feature flag.
 *
 * @param {import('express').Request} _req
 * @param {import('express').Response} _res
 * @param {import('express').NextFunction} next
 * @returns {void}
 */
const requireMortuaryWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('mortuary_workspace_v1')) {
    return next(new HttpError('errors.mortuary.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireMortuaryWorkspaceV1);

router.get(
  '/',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(MORTUARY_READ_SCOPES, 'permission'),
  mortuaryWorkspaceController.getWorkspace
);

router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(MORTUARY_READ_SCOPES, 'permission'),
  mortuaryWorkspaceController.getLookups
);

module.exports = router;
