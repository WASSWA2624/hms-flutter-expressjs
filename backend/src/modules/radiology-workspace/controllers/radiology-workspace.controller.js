const radiologyWorkspaceService = require('@services/radiology-workspace/radiology-workspace.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const getRadiologyWorkbench = asyncHandler(async (req, res) => {
  const {
    stage,
    status,
    modality,
    from,
    to,
    patient_id,
    encounter_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc',
  } = req.query;

  const data = await radiologyWorkspaceService.getRadiologyWorkbench(
    {
      stage,
      status,
      modality,
      from,
      to,
      patient_id,
      encounter_id,
      search,
    },
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendSuccess(res, 200, 'messages.radiology_workspace.workbench.success', data);
});

const getRadiologyReferenceData = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.getRadiologyReferenceData(req.query, {
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
  });
  return sendSuccess(res, 200, 'messages.radiology_workspace.reference_data.success', data);
});

const createRadiologyOrder = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.createRadiologyOrder(
    req.body,
    req.user?.id,
    req.ip,
    {
      tenant_id: req.user?.tenant_id,
      facility_id: req.user?.facility_id,
    }
  );
  return sendSuccess(res, 201, 'messages.radiology_workspace.order.create_success', data);
});

const getRadiologyOrderWorkflow = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.getRadiologyOrderWorkflow(req.params.id);
  return sendSuccess(res, 200, 'messages.radiology_workspace.workflow.success', data);
});

const assignRadiologyOrder = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.assignRadiologyOrder(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.assign.success', data);
});

const startRadiologyOrder = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.startRadiologyOrder(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.start.success', data);
});

const completeRadiologyOrder = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.completeRadiologyOrder(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.complete.success', data);
});

const cancelRadiologyOrder = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.cancelRadiologyOrder(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.cancel.success', data);
});

const createRadiologyStudy = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.createRadiologyStudy(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 201, 'messages.radiology_workspace.study.create_success', data);
});

const initStudyAssetUpload = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.initStudyAssetUpload(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.asset.init_upload_success', data);
});

const commitStudyAssetUpload = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.commitStudyAssetUpload(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 201, 'messages.radiology_workspace.asset.commit_upload_success', data);
});

const syncStudyToPacs = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.syncStudyToPacs(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.pacs.sync_success', data);
});

const draftRadiologyResult = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.draftRadiologyResult(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.result.draft_success', data);
});

const finalizeRadiologyResult = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.finalizeRadiologyResult(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.result.finalize_success', data);
});

const requestRadiologyResultFinalization = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.requestRadiologyResultFinalization(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.result.request_finalization_success', data);
});

const attestRadiologyResultFinalization = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.attestRadiologyResultFinalization(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.result.attest_finalization_success', data);
});

const addendumRadiologyResult = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.addendumRadiologyResult(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 201, 'messages.radiology_workspace.result.addendum_success', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await radiologyWorkspaceService.resolveLegacyRouteIdentifier(
    req.params.resource,
    req.params.id
  );
  return sendSuccess(res, 200, 'messages.radiology_workspace.resolve_legacy.success', data);
});

module.exports = {
  getRadiologyWorkbench,
  getRadiologyReferenceData,
  createRadiologyOrder,
  getRadiologyOrderWorkflow,
  assignRadiologyOrder,
  startRadiologyOrder,
  completeRadiologyOrder,
  cancelRadiologyOrder,
  createRadiologyStudy,
  initStudyAssetUpload,
  commitStudyAssetUpload,
  syncStudyToPacs,
  draftRadiologyResult,
  finalizeRadiologyResult,
  requestRadiologyResultFinalization,
  attestRadiologyResultFinalization,
  addendumRadiologyResult,
  resolveLegacyRoute,
};
