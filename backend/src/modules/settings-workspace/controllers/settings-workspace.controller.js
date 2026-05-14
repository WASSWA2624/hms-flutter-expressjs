const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const settingsWorkspaceService = require('@services/settings-workspace/settings-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const data = await settingsWorkspaceService.getWorkspace(req.query, req.user);
  return sendSuccess(res, 200, 'messages.settings_workspace.workspace.success', data);
});

const getReferenceData = asyncHandler(async (req, res) => {
  const data = await settingsWorkspaceService.getReferenceData(req.query, req.user);
  return sendSuccess(res, 200, 'messages.settings_workspace.reference_data.success', data);
});

module.exports = {
  getReferenceData,
  getWorkspace,
};
