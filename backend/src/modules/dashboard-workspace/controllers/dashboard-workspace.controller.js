const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const dashboardWorkspaceService = require('@services/dashboard-workspace/dashboard-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order = 'desc', ...filters } = req.query;
  const data = await dashboardWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  return sendSuccess(res, 200, 'messages.dashboard_workspace.workspace.success', data);
});

const getLookups = asyncHandler(async (req, res) => {
  const data = await dashboardWorkspaceService.getLookups(req.query, req.user);
  return sendSuccess(res, 200, 'messages.dashboard_workspace.lookups.success', data);
});

module.exports = {
  getLookups,
  getWorkspace,
};
