const express = require('express');
const router = express.Router();
const accountsWorkspaceController = require('@controllers/accounts-workspace/accounts-workspace.controller');
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

const ACCOUNTS_READ_SCOPES = [
  PERMISSIONS.ACCOUNTS_READ,
  PERMISSIONS.ACCOUNTS_WRITE,
];

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
