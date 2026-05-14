const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const getLabWorkbench = asyncHandler(async (req, res) => {
  const {
    stage,
    status,
    criticality,
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

  const data = await labWorkspaceService.getLabWorkbench(
    {
      stage,
      status,
      criticality,
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

  return sendSuccess(res, 200, 'messages.lab_workspace.workbench.success', data);
});

const getLabOrderWorkflow = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.getLabOrderWorkflow(req.params.id);
  return sendSuccess(res, 200, 'messages.lab_workspace.workflow.success', data);
});

const collectLabOrder = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.collectLabOrder(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.lab_workspace.collect.success', data);
});

const receiveLabSample = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.receiveLabSample(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.lab_workspace.receive.success', data);
});

const rejectLabSample = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.rejectLabSample(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.lab_workspace.reject.success', data);
});

const releaseLabOrderItem = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.releaseLabOrderItem(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.lab_workspace.release.success', data);
});

const reverseLabOrderWorkflow = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.reverseLabOrderWorkflow(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.lab_workspace.reverse.success', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await labWorkspaceService.resolveLegacyRouteIdentifier(
    req.params.resource,
    req.params.id
  );
  return sendSuccess(res, 200, 'messages.lab_workspace.resolve_legacy.success', data);
});

module.exports = {
  getLabWorkbench,
  getLabOrderWorkflow,
  collectLabOrder,
  receiveLabSample,
  rejectLabSample,
  releaseLabOrderItem,
  reverseLabOrderWorkflow,
  resolveLegacyRoute,
};
