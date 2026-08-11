/**
 * Chart Account routes
 *
 * @module modules/chart-account/routes
 * @description Chart Account endpoints mounted at /api/v1/chart-accounts
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const chartAccountController = require('@controllers/chart-account/chart-account.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createChartAccountSchema,
  updateChartAccountSchema,
  chartAccountIdParamsSchema,
  listChartAccountsQuerySchema
} = require('@validations/chart-account/chart-account.schema');

/** Read — (`accounts:read` ∪ `accounts:write`) aligns with Accounts workspace GETs. */
const ACCOUNTS_READ_SCOPES = [
  PERMISSIONS.ACCOUNTS_READ,
  PERMISSIONS.ACCOUNTS_WRITE,
];

/**
 * Chart mutations — `accounts:write` or admin write equivalents
 * (accounts.md §9 / frontend `accountsChartWriteRequirement`).
 */
const ACCOUNTS_CHART_WRITE_SCOPES = [
  PERMISSIONS.ACCOUNTS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
];

/**
 * @description List chart accounts with pagination and filters
 * @method GET
 * @route /api/v1/chart-accounts/
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_READ ∪ ACCOUNTS_WRITE
 */
router.get(
  '/',
  validateRequest({ query: listChartAccountsQuerySchema }),
  authenticate(),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  chartAccountController.listChartAccounts
);

/**
 * @description Get chart account by ID
 * @method GET
 * @route /api/v1/chart-accounts/:id
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_READ ∪ ACCOUNTS_WRITE
 */
router.get(
  '/:id',
  validateRequest({ params: chartAccountIdParamsSchema }),
  authenticate(),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  chartAccountController.getChartAccountById
);

/**
 * @description Create new chart account
 * @method POST
 * @route /api/v1/chart-accounts/
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_WRITE ∪ TENANT_ADMIN ∪ FACILITY_ADMIN
 */
router.post(
  '/',
  validateRequest({ body: createChartAccountSchema }),
  authenticate(),
  authorize(ACCOUNTS_CHART_WRITE_SCOPES, 'permission'),
  chartAccountController.createChartAccount
);

/**
 * @description Update chart account (including deactivate via is_active:false)
 * @method PUT
 * @route /api/v1/chart-accounts/:id
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_WRITE ∪ TENANT_ADMIN ∪ FACILITY_ADMIN
 */
router.put(
  '/:id',
  validateRequest({ params: chartAccountIdParamsSchema, body: updateChartAccountSchema }),
  authenticate(),
  authorize(ACCOUNTS_CHART_WRITE_SCOPES, 'permission'),
  chartAccountController.updateChartAccount
);

module.exports = router;
