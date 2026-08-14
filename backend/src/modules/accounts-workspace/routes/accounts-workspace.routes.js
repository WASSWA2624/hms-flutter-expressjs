const express = require('express');
const router = express.Router();
const accountsWorkspaceController = require('@controllers/accounts-workspace/accounts-workspace.controller');
const fiscalPeriodController = require('@controllers/accounts-workspace/fiscal-period.controller');
const departmentController = require('@controllers/accounts-workspace/department-cost-centre.controller');
const documentSequenceController = require('@controllers/accounts-workspace/document-number-sequence.controller');
const postingRuleController = require('@controllers/accounts-workspace/posting-rule.controller');
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
const {
  departmentsQuerySchema,
  departmentIdentifierParamsSchema,
  departmentActionParamsSchema,
  createDepartmentSchema,
  updateDepartmentSchema,
  departmentActionSchema,
} = require('@validations/accounts-workspace/department-cost-centre.schema');
const {
  documentSequencesQuerySchema,
  documentSequenceIdentifierParamsSchema,
  documentSequenceActionParamsSchema,
  createDocumentSequenceSchema,
  updateDocumentSequenceSchema,
  documentSequenceActionSchema,
} = require('@validations/accounts-workspace/document-number-sequence.schema');
const {
  postingRulesQuerySchema,
  postingRuleIdentifierParamsSchema,
  postingRuleActionParamsSchema,
  createPostingRuleSchema,
  updatePostingRuleSchema,
  postingRuleActionSchema,
} = require('@validations/accounts-workspace/posting-rule.schema');

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

/**
 * Setup & Controls → Departments & Cost Centres.
 *
 * The department record is owned by `modules/department`; these routes expose
 * its finance projection. Records are addressed by their public
 * `human_friendly_id`, and archive is a status transition rather than a
 * delete, so there is no DELETE route.
 */
router.get(
  '/departments-and-cost-centres',
  validateRequest({ query: departmentsQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  departmentController.listDepartments
);

router.get(
  '/departments-and-cost-centres/:departmentIdentifier',
  validateRequest({ params: departmentIdentifierParamsSchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  departmentController.getDepartment
);

router.post(
  '/departments-and-cost-centres',
  validateRequest({ body: createDepartmentSchema }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  departmentController.createDepartment
);

router.put(
  '/departments-and-cost-centres/:departmentIdentifier',
  validateRequest({
    params: departmentIdentifierParamsSchema,
    body: updateDepartmentSchema,
  }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  departmentController.updateDepartment
);

router.post(
  '/departments-and-cost-centres/:departmentIdentifier/:action',
  validateRequest({
    params: departmentActionParamsSchema,
    body: departmentActionSchema,
  }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  departmentController.applyDepartmentAction
);

/**
 * Setup & Controls → Posting Rules.
 *
 * Records are addressed by their public `human_friendly_id`. Archive is a
 * status transition, not a delete, so there is no DELETE route.
 */
router.get(
  '/posting-rules',
  validateRequest({ query: postingRulesQuerySchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  postingRuleController.listPostingRules
);

router.get(
  '/posting-rules/:postingRuleIdentifier',
  validateRequest({ params: postingRuleIdentifierParamsSchema }),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  postingRuleController.getPostingRule
);

router.post(
  '/posting-rules',
  validateRequest({ body: createPostingRuleSchema }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  postingRuleController.createPostingRule
);

router.put(
  '/posting-rules/:postingRuleIdentifier',
  validateRequest({
    params: postingRuleIdentifierParamsSchema,
    body: updatePostingRuleSchema,
  }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  postingRuleController.updatePostingRule
);

router.post(
  '/posting-rules/:postingRuleIdentifier/:action',
  validateRequest({
    params: postingRuleActionParamsSchema,
    body: postingRuleActionSchema,
  }),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  postingRuleController.applyPostingRuleAction
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
