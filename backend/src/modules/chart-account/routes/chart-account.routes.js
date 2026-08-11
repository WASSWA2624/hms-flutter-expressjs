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

/**
 * @description List chart accounts with pagination and filters
 * @method GET
 * @route /api/v1/chart-accounts/
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_READ
 */
router.get(
  '/',
  validateRequest({ query: listChartAccountsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.ACCOUNTS_READ, 'permission'),
  chartAccountController.listChartAccounts
);

/**
 * @description Get chart account by ID
 * @method GET
 * @route /api/v1/chart-accounts/:id
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_READ
 */
router.get(
  '/:id',
  validateRequest({ params: chartAccountIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.ACCOUNTS_READ, 'permission'),
  chartAccountController.getChartAccountById
);

/**
 * @description Create new chart account
 * @method POST
 * @route /api/v1/chart-accounts/
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_WRITE
 */
router.post(
  '/',
  validateRequest({ body: createChartAccountSchema }),
  authenticate(),
  authorize(PERMISSIONS.ACCOUNTS_WRITE, 'permission'),
  chartAccountController.createChartAccount
);

/**
 * @description Update chart account (including deactivate via is_active:false)
 * @method PUT
 * @route /api/v1/chart-accounts/:id
 * @authentication Required (JWT)
 * @permissions ACCOUNTS_WRITE
 */
router.put(
  '/:id',
  validateRequest({ params: chartAccountIdParamsSchema, body: updateChartAccountSchema }),
  authenticate(),
  authorize(PERMISSIONS.ACCOUNTS_WRITE, 'permission'),
  chartAccountController.updateChartAccount
);

module.exports = router;
