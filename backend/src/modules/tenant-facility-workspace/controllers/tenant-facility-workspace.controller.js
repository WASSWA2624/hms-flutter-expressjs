const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const tenantFacilityWorkspaceService = require('@services/tenant-facility-workspace/tenant-facility-workspace.service');

const getSetup = asyncHandler(async (req, res) => {
  const data = await tenantFacilityWorkspaceService.getSetup(req.query, req.user);
  return sendSuccess(res, 200, 'messages.tenant_facility_workspace.setup.success', data);
});

module.exports = {
  getSetup,
};
