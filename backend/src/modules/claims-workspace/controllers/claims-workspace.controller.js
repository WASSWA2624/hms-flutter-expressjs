/**
 * Claims workspace controller
 *
 * @module modules/claims-workspace/controllers
 * @description Request handlers for the insurance and claims workspace aggregator.
 * Per response-format.mdc: all handlers use standardized response helpers.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const claimsWorkspaceService = require('@services/claims-workspace/claims-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { facility_id, patient_id, search } = req.query;
  const data = await claimsWorkspaceService.getWorkspace(
    { facility_id, patient_id, search },
    req.user
  );
  return sendSuccess(res, 200, 'messages.claims_workspace.workspace.success', data);
});

const getWorkItems = asyncHandler(async (req, res) => {
  const {
    queue,
    kind,
    status,
    facility_id,
    patient_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
  } = req.query;

  const data = await claimsWorkspaceService.getWorkItems(
    { queue, kind, status, facility_id, patient_id, search },
    Number(page),
    Number(limit),
    req.user
  );

  return sendPaginated(res, 'messages.claims_workspace.work_items.success', data.items, data.pagination);
});

const getLookups = asyncHandler(async (req, res) => {
  const { facility_id } = req.query;
  const data = await claimsWorkspaceService.getLookups({ facility_id }, req.user);
  return sendSuccess(res, 200, 'messages.claims_workspace.lookups.success', data);
});

const getAuthorizationContext = asyncHandler(async (req, res) => {
  const {
    patient_id,
    admission_id,
    encounter_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
  } = req.query;

  const data = await claimsWorkspaceService.getAuthorizationContext(
    { patient_id, admission_id, encounter_id },
    Number(page),
    Number(limit),
    req.user
  );

  return sendPaginated(res, 'messages.claims_workspace.authorization_context.success', data.items, data.pagination);
});

module.exports = {
  getWorkspace,
  getWorkItems,
  getLookups,
  getAuthorizationContext,
};
