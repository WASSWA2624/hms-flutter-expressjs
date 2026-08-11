const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const accountsWorkspaceService = require('@services/accounts-workspace/accounts-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const data = await accountsWorkspaceService.getWorkspace(req.query, req.user);
  return sendSuccess(res, 200, 'Accounts workspace loaded.', data);
});

const listWorkItems = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, ...filters } = req.query;
  const result = await accountsWorkspaceService.listWorkItems(
    filters,
    Number(page),
    Number(limit),
    req.user
  );
  return sendPaginated(
    res,
    'Accounts work items loaded.',
    result.items,
    result.pagination
  );
});

const listGlAccounts = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, ...filters } = req.query;
  const result = await accountsWorkspaceService.listGlAccounts(
    filters,
    Number(page),
    Number(limit),
    req.user
  );
  return sendPaginated(
    res,
    'General ledger accounts loaded.',
    result.items,
    result.pagination
  );
});

const getAccountLedger = asyncHandler(async (req, res) => {
  const { accountIdentifier } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, ...filters } = req.query;
  const data = await accountsWorkspaceService.getAccountLedger(
    accountIdentifier,
    filters,
    Number(page),
    Number(limit),
    req.user
  );
  return sendSuccess(res, 200, 'Account ledger loaded.', data);
});

const listPatientLedgers = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, ...filters } = req.query;
  const data = await accountsWorkspaceService.listPatientLedgers(
    filters,
    Number(page),
    Number(limit),
    req.user
  );
  return sendSuccess(res, 200, 'Patient ledgers loaded.', data);
});

const getPatientLedger = asyncHandler(async (req, res) => {
  const { patientIdentifier } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, from, to } = req.query;
  const data = await accountsWorkspaceService.getPatientLedger(
    patientIdentifier,
    { from, to },
    Number(page),
    Number(limit),
    req.user
  );
  return sendSuccess(res, 200, 'Patient ledger loaded.', data);
});

module.exports = {
  getWorkspace,
  listWorkItems,
  listGlAccounts,
  getAccountLedger,
  listPatientLedgers,
  getPatientLedger,
};
