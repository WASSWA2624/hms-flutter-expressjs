/**
 * Claims workspace routes
 *
 * @module modules/claims-workspace/routes
 * @description Insurance and claims workspace aggregator mounted at
 * /api/v1/claims-workspace. Read-only orchestration over coverage plans,
 * pre-authorizations, and insurance claims. Mutations stay on the dedicated
 * coverage-plan, pre-authorization, and insurance-claim modules.
 *
 * Per module-creation.mdc: apply authentication + authorization per route.
 * All endpoints require billing read access and the insurance-claims module
 * entitlement (enforced globally by enforceModuleEntitlement).
 */

const express = require('express');
const router = express.Router();
const claimsWorkspaceController = require('@controllers/claims-workspace/claims-workspace.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  workItemsQuerySchema,
  lookupsQuerySchema,
  authorizationContextQuerySchema,
} = require('@validations/claims-workspace/claims-workspace.schema');

const CLAIMS_READ_SCOPES = [PERMISSIONS.BILLING_READ];

router.use(authenticate());

/**
 * @description Aggregated insurance and claims workspace (summary, queues, timeline)
 * @method GET
 * @route /api/v1/claims-workspace/workspace
 */
router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(CLAIMS_READ_SCOPES, 'permission'),
  claimsWorkspaceController.getWorkspace
);

/**
 * @description Merged claim + pre-authorization work items (paginated worklist)
 * @method GET
 * @route /api/v1/claims-workspace/work-items
 */
router.get(
  '/work-items',
  validateRequest({ query: workItemsQuerySchema }),
  authorize(CLAIMS_READ_SCOPES, 'permission'),
  claimsWorkspaceController.getWorkItems
);

/**
 * @description Claim preparation lookups (coverage plans + billable invoices)
 * @method GET
 * @route /api/v1/claims-workspace/lookups
 */
router.get(
  '/lookups',
  validateRequest({ query: lookupsQuerySchema }),
  authorize(CLAIMS_READ_SCOPES, 'permission'),
  claimsWorkspaceController.getLookups
);

/**
 * @description Authorization context for an admission/encounter/patient gate
 * @method GET
 * @route /api/v1/claims-workspace/authorizations/context
 */
router.get(
  '/authorizations/context',
  validateRequest({ query: authorizationContextQuerySchema }),
  authorize(CLAIMS_READ_SCOPES, 'permission'),
  claimsWorkspaceController.getAuthorizationContext
);

module.exports = router;
