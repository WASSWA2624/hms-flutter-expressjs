/**
 * Triage controller
 *
 * @module modules/triage/controllers
 * @description Handles Triage queue, vitals, assignment, and routing requests.
 */

const triageService = require('@services/triage/triage.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildAuditContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  roles: req.user?.roles || (req.user?.role ? [req.user.role] : []),
  ip_address: req.ip,
  user_agent: req.get('user-agent')
});

const listTriageQueue = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    provider_user_id,
    queue_scope,
    encounter_type,
    triage_status,
    stage,
    urgency_level,
    triage_level,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'started_at',
    order = 'asc'
  } = req.query;

  const result = await triageService.listTriageQueue(
    {
      tenant_id: tenant_id || req.user?.tenant_id,
      facility_id: facility_id || req.user?.facility_id,
      patient_id,
      provider_user_id: queue_scope === 'ASSIGNED' && !provider_user_id ? req.user?.id : provider_user_id,
      queue_scope,
      encounter_type,
      triage_status: triage_status || stage,
      urgency_level: urgency_level || triage_level,
      search
    },
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'Triage queue loaded successfully.', result.items, result.pagination);
});

const getTriageCase = asyncHandler(async (req, res) => {
  const flow = await triageService.getTriageCase(req.params.id, buildAuditContext(req));
  return sendSuccess(res, 200, 'Triage case loaded successfully.', flow);
});

const recordVitals = asyncHandler(async (req, res) => {
  const flow = await triageService.recordVitals(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'Triage vitals saved successfully.', flow);
});

const assignProvider = asyncHandler(async (req, res) => {
  const flow = await triageService.assignProvider(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'Triage provider assigned successfully.', flow);
});

const routeFromTriage = asyncHandler(async (req, res) => {
  const flow = await triageService.routeFromTriage(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'Triage route saved successfully.', flow);
});

const correctStage = asyncHandler(async (req, res) => {
  const flow = await triageService.correctStage(req.params.id, req.body, buildAuditContext(req));
  return sendSuccess(res, 200, 'Triage stage corrected successfully.', flow);
});

module.exports = {
  listTriageQueue,
  getTriageCase,
  recordVitals,
  assignProvider,
  routeFromTriage,
  correctStage
};
