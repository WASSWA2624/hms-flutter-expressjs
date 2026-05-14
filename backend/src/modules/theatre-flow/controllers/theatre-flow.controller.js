/**
 * Theatre flow controller
 */

const theatreFlowService = require('@services/theatre-flow/theatre-flow.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildAuditContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  roles: Array.isArray(req.user?.roles) ? req.user.roles : [],
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listTheatreFlows = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    encounter_id,
    queue_scope,
    status,
    stage,
    room_id,
    surgeon_user_id,
    anesthetist_user_id,
    anesthesia_status,
    post_op_status,
    scheduled_from,
    scheduled_to,
    finalized,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'scheduled_at',
    order = 'desc',
  } = req.query;

  const result = await theatreFlowService.listTheatreFlows(
    {
      tenant_id,
      facility_id,
      patient_id,
      encounter_id,
      queue_scope,
      status,
      stage,
      room_id,
      surgeon_user_id,
      anesthetist_user_id,
      anesthesia_status,
      post_op_status,
      scheduled_from,
      scheduled_to,
      finalized,
      search,
    },
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.theatre_flow.list.success',
    result.items,
    result.pagination
  );
});

const getTheatreFlowById = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.getTheatreFlowById(req.params.id, {
    include_timeline: req.query?.include_timeline,
  });
  return sendSuccess(res, 200, 'messages.theatre_flow.get.success', flow);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const resolution = await theatreFlowService.resolveLegacyRoute(
    req.params.resource,
    req.params.id
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.resolve_legacy.success',
    resolution
  );
});

const startTheatreFlow = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.startTheatreFlow(
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 201, 'messages.theatre_flow.start.success', flow);
});

const updateStage = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.updateStage(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.update_stage.success',
    flow
  );
});

const upsertAnesthesiaRecord = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.upsertAnesthesiaRecord(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.upsert_anesthesia_record.success',
    flow
  );
});

const addAnesthesiaObservation = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.addAnesthesiaObservation(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.add_anesthesia_observation.success',
    flow
  );
});

const upsertPostOpNote = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.upsertPostOpNote(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.upsert_post_op_note.success',
    flow
  );
});

const toggleChecklistItem = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.toggleChecklistItem(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.toggle_checklist_item.success',
    flow
  );
});

const assignResource = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.assignResource(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.assign_resource.success',
    flow
  );
});

const releaseResource = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.releaseResource(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.release_resource.success',
    flow
  );
});

const finalizeRecord = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.finalizeRecord(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.finalize_record.success',
    flow
  );
});

const reopenRecord = asyncHandler(async (req, res) => {
  const flow = await theatreFlowService.reopenRecord(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(
    res,
    200,
    'messages.theatre_flow.reopen_record.success',
    flow
  );
});

module.exports = {
  listTheatreFlows,
  getTheatreFlowById,
  resolveLegacyRoute,
  startTheatreFlow,
  updateStage,
  upsertAnesthesiaRecord,
  addAnesthesiaObservation,
  upsertPostOpNote,
  toggleChecklistItem,
  assignResource,
  releaseResource,
  finalizeRecord,
  reopenRecord,
};

