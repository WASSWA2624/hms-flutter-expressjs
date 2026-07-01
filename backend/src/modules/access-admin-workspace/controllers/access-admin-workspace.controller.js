const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const accessAdminWorkspaceService = require('@services/access-admin-workspace/access-admin-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const page = Number(req.query.page) || 1;
  const limit = Number(req.query.limit) || 20;
  const data = await accessAdminWorkspaceService.getWorkspace(
    req.query,
    page,
    limit,
    req.user
  );
  return sendSuccess(res, 200, 'messages.access_admin_workspace.workspace.success', data);
});

const getReferenceData = asyncHandler(async (req, res) => {
  const data = await accessAdminWorkspaceService.getReferenceData(req.query, req.user);
  return sendSuccess(res, 200, 'messages.access_admin_workspace.reference_data.success', data);
});

const getUserDetail = asyncHandler(async (req, res) => {
  const data = await accessAdminWorkspaceService.getUserDetail(
    req.params.userIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(res, 200, 'messages.access_admin_workspace.user_detail.success', data);
});

const resetDemoUserPassword = asyncHandler(async (req, res) => {
  const data = await accessAdminWorkspaceService.resetDemoUserPassword(
    req.params.userIdentifier,
    req.user
  );
  return sendSuccess(res, 200, 'messages.access_admin_workspace.demo_reset.success', data);
});

const activateRegistration = asyncHandler(async (req, res) => {
  const data = await accessAdminWorkspaceService.activateRegistration(
    req.params.userIdentifier,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.access_admin_workspace.registration_activated.success', data);
});

const rejectRegistration = asyncHandler(async (req, res) => {
  const data = await accessAdminWorkspaceService.rejectRegistration(
    req.params.userIdentifier,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.access_admin_workspace.registration_rejected.success', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await accessAdminWorkspaceService.resolveLegacyRoute(
    req.params.resource,
    req.params.id
  );
  return sendSuccess(res, 200, 'messages.access_admin_workspace.resolve_legacy.success', data);
});

module.exports = {
  activateRegistration,
  getReferenceData,
  getUserDetail,
  getWorkspace,
  rejectRegistration,
  resetDemoUserPassword,
  resolveLegacyRoute,
};
