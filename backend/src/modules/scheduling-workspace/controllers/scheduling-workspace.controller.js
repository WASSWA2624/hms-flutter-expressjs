const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const schedulingWorkspaceService = require('@services/scheduling-workspace/scheduling-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const data = await schedulingWorkspaceService.getWorkspace(
    { ...filters, sort_by, order },
    Number(page),
    Number(limit)
  );
  return sendSuccess(res, 200, 'messages.scheduling_workspace.workspace.success', data);
});

const getReferenceData = asyncHandler(async (req, res) => {
  const data = await schedulingWorkspaceService.getReferenceData(req.query);
  return sendSuccess(res, 200, 'messages.scheduling_workspace.reference_data.success', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await schedulingWorkspaceService.resolveLegacyRouteIdentifier(
    req.params.resource,
    req.params.id
  );
  return sendSuccess(res, 200, 'messages.scheduling_workspace.resolve_legacy.success', data);
});

module.exports = {
  getWorkspace,
  getReferenceData,
  resolveLegacyRoute,
};
