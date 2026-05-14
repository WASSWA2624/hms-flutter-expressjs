const reportsWorkspaceService = require('@services/reports-workspace/reports-workspace.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order = 'desc', ...filters } = req.query;
  const data = await reportsWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'messages.reports_workspace.workspace.success', data);
});

const getLookups = asyncHandler(async (req, res) => {
  const data = await reportsWorkspaceService.getLookups(req.query, req.user);
  return sendSuccess(res, 200, 'messages.reports_workspace.lookups.success', data);
});

module.exports = {
  getLookups,
  getWorkspace,
};
