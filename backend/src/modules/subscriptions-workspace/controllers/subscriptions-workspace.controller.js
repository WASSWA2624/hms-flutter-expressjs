const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const subscriptionsWorkspaceService = require('@services/subscriptions-workspace/subscriptions-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order = 'desc', ...filters } = req.query;
  const data = await subscriptionsWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'messages.subscriptions_workspace.workspace.success', data);
});

const getReferenceData = asyncHandler(async (req, res) => {
  const data = await subscriptionsWorkspaceService.getReferenceData(req.query, req.user);
  return sendSuccess(res, 200, 'messages.subscriptions_workspace.reference_data.success', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await subscriptionsWorkspaceService.resolveLegacyRoute(
    req.params.resource,
    req.params.id,
    req.user
  );
  return sendSuccess(res, 200, 'messages.subscriptions_workspace.resolve_legacy.success', data);
});

module.exports = {
  getReferenceData,
  getWorkspace,
  resolveLegacyRoute,
};
