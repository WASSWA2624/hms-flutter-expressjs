/**
 * Therapy flow controller
 */

const therapyFlowService = require('@services/therapy-flow/therapy-flow.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildAuditContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  roles: Array.isArray(req.user?.roles) ? req.user.roles : [],
  ip_address: req.ip,
  user_agent: req.get('user-agent')});

const listTherapyFlows = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    encounter_id,
    therapist_id,
    queue_scope,
    therapy_status,
    source_kind,
    scheduled_from,
    scheduled_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'updated_at',
    order = 'desc'} = req.query;

  const result = await therapyFlowService.listTherapyFlows(
    {
      tenant_id,
      facility_id,
      patient_id,
      encounter_id,
      therapist_id,
      queue_scope,
      therapy_status,
      source_kind,
      scheduled_from,
      scheduled_to,
      search},
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.therapy_flow.list.success',
    result.items,
    result.pagination
  );
});

const getTherapyFlowById = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.getTherapyFlowById(req.params.id, {
    include_timeline: req.query?.include_timeline});
  return sendSuccess(res, 200, 'messages.therapy_flow.get.success', flow);
});

const createTherapyReferral = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.createTherapyReferral(
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 201, 'messages.therapy_flow.referral.created', flow);
});

const acceptReferral = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.acceptReferral(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.accept_referral.success', flow);
});

const recordAssessment = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.recordAssessment(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.record_assessment.success', flow);
});

const scheduleSession = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.scheduleSession(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.schedule_session.success', flow);
});

const recordSession = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.recordSession(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.record_session.success', flow);
});

const markAttendance = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.markAttendance(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.mark_attendance.success', flow);
});

const updatePlan = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.updatePlan(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.update_plan.success', flow);
});

const addProgressNote = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.addProgressNote(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.add_progress_note.success', flow);
});

const scheduleFollowUp = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.scheduleFollowUp(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.schedule_follow_up.success', flow);
});

const closeEpisode = asyncHandler(async (req, res) => {
  const flow = await therapyFlowService.closeEpisode(
    req.params.id,
    req.body,
    buildAuditContext(req)
  );
  return sendSuccess(res, 200, 'messages.therapy_flow.close_episode.success', flow);
});

module.exports = {
  listTherapyFlows,
  getTherapyFlowById,
  createTherapyReferral,
  acceptReferral,
  recordAssessment,
  scheduleSession,
  recordSession,
  markAttendance,
  updatePlan,
  addProgressNote,
  scheduleFollowUp,
  closeEpisode};
