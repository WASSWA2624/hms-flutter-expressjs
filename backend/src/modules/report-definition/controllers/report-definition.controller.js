const reportDefinitionService = require('@services/report-definition/report-definition.service');
const { asyncHandler } = require('@lib/async');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  tenant_id: req.user?.tenant_id || req.user?.tenantId || null,
  facility_id: req.user?.facility_id || req.user?.facilityId || null,
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listReportDefinitions = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await reportDefinitionService.listReportDefinitions(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.report_definition.list_success', result.reportDefinitions, result.pagination);
});

const getReportDefinitionById = asyncHandler(async (req, res) => {
  const result = await reportDefinitionService.getReportDefinitionById(req.params.id, req.user);
  sendSuccess(res, 200, 'messages.report_definition.get_success', result);
});

const createReportDefinition = asyncHandler(async (req, res) => {
  const result = await reportDefinitionService.createReportDefinition(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.report_definition.create_success', result);
});

const updateReportDefinition = asyncHandler(async (req, res) => {
  const result = await reportDefinitionService.updateReportDefinition(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.report_definition.update_success', result);
});

const deleteReportDefinition = asyncHandler(async (req, res) => {
  await reportDefinitionService.deleteReportDefinition(req.params.id, buildContext(req));
  sendNoContent(res);
});

const runReportDefinitionNow = asyncHandler(async (req, res) => {
  const result = await reportDefinitionService.runReportDefinitionNow(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.report_run.create_success', result);
});

module.exports = {
  createReportDefinition,
  deleteReportDefinition,
  getReportDefinitionById,
  listReportDefinitions,
  runReportDefinitionNow,
  updateReportDefinition,
};
