/**
 * IPD flow controller
 */

const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildAuditContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listIpdFlows = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    queue_scope,
    stage,
    ward_id,
    transfer_status,
    has_active_bed,
    include_icu,
    icu_queue_scope,
    icu_status,
    critical_severity,
    has_critical_alert,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'admitted_at',
    order = 'desc',
  } = req.query;

  const result = await ipdFlowService.listIpdFlows(
    {
      tenant_id,
      facility_id,
      patient_id,
      queue_scope,
      stage,
      ward_id,
      transfer_status,
      has_active_bed,
      include_icu,
      icu_queue_scope,
      icu_status,
      critical_severity,
      has_critical_alert,
      search,
    },
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'messages.ipd_flow.list.success', result.items, result.pagination);
});

const getIpdFlowById = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.getIpdFlowById(req.params.id, {
    include_icu: req.query?.include_icu,
  });
  return sendSuccess(res, 200, 'messages.ipd_flow.get.success', flow);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const resolution = await ipdFlowService.resolveLegacyRoute(req.params.resource, req.params.id);
  return sendSuccess(res, 200, 'messages.ipd_flow.resolve_legacy.success', resolution);
});

const startIpdFlow = asyncHandler(async (req, res) => {
  const payload = {
    ...req.body,
    tenant_id: req.body?.tenant_id || req.user?.tenant_id,
  };

  const flow = await ipdFlowService.startIpdFlow(payload, buildAuditContext(req));
  return sendSuccess(res, 201, 'messages.ipd_flow.start.success', flow);
});

const assignBed = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.assignBed(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.assign_bed.success', flow);
});

const releaseBed = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.releaseBed(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.release_bed.success', flow);
});


const rejectAdmissionRequest = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.rejectAdmissionRequest(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.ipd_flow.reject_admission.success', flow);
});

const requestTransfer = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.requestTransfer(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.request_transfer.success', flow);
});

const updateTransfer = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.updateTransfer(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.update_transfer.success', flow);
});

const addWardRound = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.addWardRound(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.add_ward_round.success', flow);
});

const addNursingNote = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.addNursingNote(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.add_nursing_note.success', flow);
});

const addMedicationAdministration = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.addMedicationAdministration(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.ipd_flow.add_medication_administration.success', flow);
});

const planDischarge = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.planDischarge(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.plan_discharge.success', flow);
});

const finalizeDischarge = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.finalizeDischarge(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.finalize_discharge.success', flow);
});

const startIcuStay = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.startIcuStay(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.start_icu_stay.success', flow);
});

const endIcuStay = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.endIcuStay(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.end_icu_stay.success', flow);
});

const addIcuObservation = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.addIcuObservation(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.add_icu_observation.success', flow);
});

const addCriticalAlert = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.addCriticalAlert(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.add_critical_alert.success', flow);
});

const resolveCriticalAlert = asyncHandler(async (req, res) => {
  const flow = await ipdFlowService.resolveCriticalAlert(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.ipd_flow.resolve_critical_alert.success', flow);
});

module.exports = {
  listIpdFlows,
  resolveLegacyRoute,
  getIpdFlowById,
  startIpdFlow,
  assignBed,
  releaseBed,
  rejectAdmissionRequest,
  requestTransfer,
  updateTransfer,
  addWardRound,
  addNursingNote,
  addMedicationAdministration,
  planDischarge,
  finalizeDischarge,
  startIcuStay,
  endIcuStay,
  addIcuObservation,
  addCriticalAlert,
  resolveCriticalAlert,
};
