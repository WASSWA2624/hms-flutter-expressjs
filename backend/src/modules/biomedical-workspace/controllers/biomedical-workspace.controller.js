const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const biomedicalWorkspaceService = require('@services/biomedical-workspace/biomedical-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const data = await biomedicalWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'messages.biomedical_workspace.workspace.success', data);
});

const getLookups = asyncHandler(async (req, res) => {
  const data = await biomedicalWorkspaceService.getLookups(req.query, req.user);
  return sendSuccess(res, 200, 'messages.biomedical_workspace.lookups.success', data);
});

const createFaultReport = asyncHandler(async (req, res) => {
  const data = await biomedicalWorkspaceService.createFaultReport(req.body, req.user, req.ip);
  return sendSuccess(res, 201, 'messages.biomedical_workspace.fault_report.success', data);
});

module.exports = {
  getWorkspace,
  getLookups,
  createFaultReport,
};
