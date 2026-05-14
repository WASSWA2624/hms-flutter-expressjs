const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const hrWorkspaceService = require('@services/hr-workspace/hr-workspace.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const data = await hrWorkspaceService.getWorkspace(filters, Number(page), Number(limit), sort_by, order);
  return sendSuccess(res, 200, 'messages.hr_workspace.workspace.success', data);
});

const getWorkItems = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const data = await hrWorkspaceService.getWorkItems(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order
  );
  return sendSuccess(res, 200, 'messages.hr_workspace.work_items.success', data);
});

const getReferenceData = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.getReferenceData(req.query);
  return sendSuccess(res, 200, 'messages.hr_workspace.reference_data.success', data);
});

const getRosterWorkflow = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.getRosterWorkflow(req.params.rosterIdentifier);
  return sendSuccess(res, 200, 'messages.hr_workspace.roster_workflow.success', data);
});

const generateRoster = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.generateRosterAssignments({
    rosterIdentifier: req.params.rosterIdentifier,
    constraints: req.body.constraints,
    replaceExistingAssignments: req.body.replace_existing_assignments,
    dryRun: req.body.dry_run,
    userId: req.user?.id,
    ipAddress: req.ip,
  });
  return sendSuccess(res, 200, 'messages.hr_workspace.roster_generate.success', data);
});

const publishRoster = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.publishRoster(req.params.rosterIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.roster_publish.success', data);
});

const overrideShift = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.overrideShiftAssignment(req.params.shiftIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.shift_override.success', data);
});

const approveSwap = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.approveSwap(req.params.swapIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.swap_approve.success', data);
});

const rejectSwap = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.rejectSwap(req.params.swapIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.swap_reject.success', data);
});

const approveLeave = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.approveLeave(req.params.leaveIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.leave_approve.success', data);
});

const rejectLeave = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.rejectLeave(req.params.leaveIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.leave_reject.success', data);
});

const previewPayrollRun = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.previewPayrollRun(req.params.payrollRunIdentifier, req.query);
  return sendSuccess(res, 200, 'messages.hr_workspace.payroll_preview.success', data);
});

const processPayrollRun = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.processPayrollRun(req.params.payrollRunIdentifier, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.hr_workspace.payroll_process.success', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await hrWorkspaceService.resolveLegacyRouteIdentifier(req.params.resource, req.params.id);
  return sendSuccess(res, 200, 'messages.hr_workspace.resolve_legacy.success', data);
});

module.exports = {
  getWorkspace,
  getWorkItems,
  getReferenceData,
  getRosterWorkflow,
  generateRoster,
  publishRoster,
  overrideShift,
  approveSwap,
  rejectSwap,
  approveLeave,
  rejectLeave,
  previewPayrollRun,
  processPayrollRun,
  resolveLegacyRoute,
};
