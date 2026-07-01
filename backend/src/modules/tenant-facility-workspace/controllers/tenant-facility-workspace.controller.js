const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const tenantFacilityWorkspaceService = require('@services/tenant-facility-workspace/tenant-facility-workspace.service');

const getSetup = asyncHandler(async (req, res) => {
  const data = await tenantFacilityWorkspaceService.getSetup(req.query, req.user);
  return sendSuccess(res, 200, 'messages.tenant_facility_workspace.setup.success', data);
});

const uploadFacilityLogo = asyncHandler(async (req, res) => {
  const facilityId = req.params.facilityId || req.params.facility_id;
  const data = await tenantFacilityWorkspaceService.uploadFacilityLogo(
    facilityId,
    req.file,
    req.user
  );
  return sendSuccess(
    res,
    200,
    'messages.tenant_facility_workspace.logo_upload.success',
    data
  );
});

module.exports = {
  getSetup,
  uploadFacilityLogo,
};
