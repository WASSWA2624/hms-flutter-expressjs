const express = require('express');
const multer = require('multer');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const { ROLES } = require('@config/roles');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const subscriptionsWorkspaceController = require('@controllers/subscriptions-workspace/subscriptions-workspace.controller');
const {
  paymentRequestBodySchema,
  planDetailQuerySchema,
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  workspaceQuerySchema} = require('@validations/subscriptions-workspace/subscriptions-workspace.schema');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 1,
    fileSize: 10 * 1024 * 1024}});

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
  authorize(ROLES.PLATFORM_ADMIN, 'role'),
  subscriptionsWorkspaceController.getWorkspace
);

router.get(
  '/plan-detail',
  validateRequest({ query: planDetailQuerySchema }),
  authorize(ROLES.PLATFORM_ADMIN, 'role'),
  subscriptionsWorkspaceController.getPlanDetail
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(ROLES.PLATFORM_ADMIN, 'role'),
  subscriptionsWorkspaceController.getReferenceData
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(ROLES.PLATFORM_ADMIN, 'role'),
  subscriptionsWorkspaceController.resolveLegacyRoute
);

router.get(
  '/upgrade-context',
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  subscriptionsWorkspaceController.getUpgradeContext
);

router.post(
  '/payment-requests',
  upload.single('proof'),
  validateRequest({ body: paymentRequestBodySchema }),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  subscriptionsWorkspaceController.submitPaymentRequest
);

module.exports = router;
