/**
 * OPD flow controller
 *
 * @module modules/opd-flow/controllers
 * @description Handles HTTP requests for OPD flow orchestration endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildAuditContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  ip_address: req.ip,
  user_agent: req.get('user-agent')
});

const listOpdFlows = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    provider_user_id,
    queue_scope,
    encounter_type,
    stage,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'started_at',
    order = 'desc'
  } = req.query;

  const result = await opdFlowService.listOpdFlows(
    {
      tenant_id,
      facility_id,
      patient_id,
      provider_user_id:
        queue_scope === 'ASSIGNED' && !provider_user_id ? req.user?.id : provider_user_id,
      queue_scope,
      encounter_type,
      stage,
      search
    },
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'messages.opd_flow.list.success', result.items, result.pagination);
});

const getOpdFlowById = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.getOpdFlowById(req.params.id);
  return sendSuccess(res, 200, 'messages.opd_flow.get.success', flow);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const resolution = await opdFlowService.resolveLegacyRoute(req.params.resource, req.params.id);
  return sendSuccess(res, 200, 'messages.opd_flow.resolve_legacy.success', resolution);
});

const startOpdFlow = asyncHandler(async (req, res) => {
  const payload = {
    ...req.body,
    tenant_id: req.body.tenant_id || req.user?.tenant_id
  };

  const flow = await opdFlowService.startOpdFlow(payload, buildAuditContext(req));
  return sendSuccess(res, 201, 'messages.opd_flow.start.success', flow);
});

const bootstrapOpdFlow = asyncHandler(async (req, res) => {
  const payload = {
    ...req.body,
    tenant_id: req.user?.tenant_id,
    facility_id: req.body?.facility_id ?? req.user?.facility_id ?? null,
    provider_user_id: req.body?.provider_user_id ?? req.user?.id ?? null,
  };

  const flow = await opdFlowService.bootstrapOpdFlow(payload, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.get.success', flow);
});

const payConsultation = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.payConsultation(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.pay_consultation.success', flow);
});

const recordVitals = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.recordVitals(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.record_vitals.success', flow);
});

const assignDoctor = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.assignDoctor(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.assign_doctor.success', flow);
});

const doctorReview = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.doctorReview(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.doctor_review.success', flow);
});

const disposition = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.disposition(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.disposition.success', flow);
});

const correctStage = asyncHandler(async (req, res) => {
  const flow = await opdFlowService.correctStage(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'messages.opd_flow.correct_stage.success', flow);
});

module.exports = {
  listOpdFlows,
  resolveLegacyRoute,
  getOpdFlowById,
  startOpdFlow,
  bootstrapOpdFlow,
  payConsultation,
  recordVitals,
  assignDoctor,
  doctorReview,
  disposition,
  correctStage
};
