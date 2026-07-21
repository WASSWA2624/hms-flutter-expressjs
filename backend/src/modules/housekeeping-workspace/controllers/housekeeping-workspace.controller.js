const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const housekeepingWorkspaceService = require('@services/housekeeping-workspace/housekeeping-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const data = await housekeepingWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'messages.housekeeping_workspace.workspace.success', data);
});

const getLookups = asyncHandler(async (req, res) => {
  const data = await housekeepingWorkspaceService.getLookups(req.query, req.user);
  return sendSuccess(res, 200, 'messages.housekeeping_workspace.lookups.success', data);
});

module.exports = {
  getWorkspace,
  getLookups,
};
