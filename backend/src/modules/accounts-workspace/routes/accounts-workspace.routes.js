const express = require('express');
const router = express.Router();
const accountsWorkspaceController = require('@controllers/accounts-workspace/accounts-workspace.controller');
const fiscalPeriodController = require('@controllers/accounts-workspace/fiscal-period.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  patientLedgersQuerySchema,
  patientLedgerParamsSchema,
  patientLedgerQuerySchema,
  workItemsQuerySchema,
  glAccountsQuerySchema,
  accountIdentifierParamsSchema,
  accountLedgerQuerySchema,
} = require('@validations/accounts-workspace/accounts-workspace.schema');
const {
  fiscalPeriodsQuerySchema,
  fiscalPeriodIdentifierParamsSchema,
  fiscalPeriodActionParamsSchema,
  createFiscalPeriodSchema,
  updateFiscalPeriodSchema,
  fiscalPeriodActionSchema,
} = require('@validations/accounts-workspace/fiscal-period.schema');

/**
 * Route / queue reads — (`accounts:read` ∪ `accounts:write`).
 * When journal / period / approve mutations land (accounts.md §9):
 * - Write: authorize(PERMISSIONS.ACCOUNTS_WRITE, 'permission')
 * - Approve/Reject (AND): chain authorize(ACCOUNTS_WRITE) then
 *   authorize(PERMISSIONS.FINANCIAL_APPROVE) — a single authorize([...]) is OR-only.
 */
const ACCOUNTS_READ_SCOPES = [
  PERMISSIONS.ACCOUNTS_READ,
  PERMISSIONS.ACCOUNTS_WRITE,
];

const ACCOUNTS_WRITE_SCOPES = [PERMISSIONS.ACCOUNTS_WRITE];

const requireAccountsWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('accounts_workspace_v1')) {
    return next(new HttpError('Accounts workspace is not enabled.', 404));
  }
  return next();
};

router.use(authenticate());
router.use(requireAccountsWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsWorkspaceController.getWorkspace
);

router.get(
  '/work-items',
  validateRequest({ query: workItemsQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsWorkspaceController.listWorkItems
);

router.get(
  '/gl-accounts',
  validateRequest({ query: glAccountsQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsWorkspaceController.listGlAccounts
);

router.get(
  '/gl-accounts/:accountIdentifier/ledger',
  validateRequest({
    params: accountIdentifierParamsSchema,
    query: accountLedgerQuerySchema,
  }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsWorkspaceController.getAccountLedger
);

/**
 * Setup & Controls → Fiscal Years & Periods.
 *
 * Records are addressed by their public `human_friendly_id`. Archive is a
 * status transition, not a delete, so there is no DELETE route.
 */
router.get(
  '/fiscal-years-and-periods',
  validateRequest({ query: fiscalPeriodsQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  fiscalPeriodController.listFiscalPeriods
);

router.get(
  '/fiscal-years-and-periods/:fiscalPeriodIdentifier',
  validateRequest({ params: fiscalPeriodIdentifierParamsSchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  fiscalPeriodController.getFiscalPeriod
);

router.post(
  '/fiscal-years-and-periods',
  validateRequest({ body: createFiscalPeriodSchema }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  fiscalPeriodController.createFiscalPeriod
);

router.put(
  '/fiscal-years-and-periods/:fiscalPeriodIdentifier',
  validateRequest({
    params: fiscalPeriodIdentifierParamsSchema,
    body: updateFiscalPeriodSchema,
  }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  fiscalPeriodController.updateFiscalPeriod
);

router.post(
  '/fiscal-years-and-periods/:fiscalPeriodIdentifier/:action',
  validateRequest({
    params: fiscalPeriodActionParamsSchema,
    body: fiscalPeriodActionSchema,
  }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  fiscalPeriodController.applyFiscalPeriodAction
);

router.get(
  '/patient-ledgers',
  validateRequest({ query: patientLedgersQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsWorkspaceController.listPatientLedgers
);

router.get(
  '/patients/:patientIdentifier/ledger',
  validateRequest({
    params: patientLedgerParamsSchema,
    query: patientLedgerQuerySchema,
  }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsWorkspaceController.getPatientLedger
);

module.exports = router;
