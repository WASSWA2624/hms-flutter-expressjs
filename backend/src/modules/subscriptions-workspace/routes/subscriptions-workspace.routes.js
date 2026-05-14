const express = require('express');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const subscriptionsWorkspaceController = require('@controllers/subscriptions-workspace/subscriptions-workspace.controller');
const {
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  workspaceQuerySchema,
} = require('@validations/subscriptions-workspace/subscriptions-workspace.schema');

const router = express.Router();

const requireSubscriptionsWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('subscriptions_workspace_v1')) {
    return next(new HttpError('errors.subscriptions.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireSubscriptionsWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  subscriptionsWorkspaceController.getWorkspace
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  subscriptionsWorkspaceController.getReferenceData
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  subscriptionsWorkspaceController.resolveLegacyRoute
);

module.exports = router;
