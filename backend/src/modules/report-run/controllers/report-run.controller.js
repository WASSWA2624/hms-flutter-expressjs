const reportRunService = require('@services/report-run/report-run.service');
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

const listReportRuns = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await reportRunService.listReportRuns(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.report_run.list_success', result.reportRuns, result.pagination);
});

const getReportRunById = asyncHandler(async (req, res) => {
  const result = await reportRunService.getReportRunById(req.params.id, req.user);
  sendSuccess(res, 200, 'messages.report_run.get_success', result);
});

const createReportRun = asyncHandler(async (req, res) => {
  const result = await reportRunService.createReportRun(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.report_run.create_success', result);
});

const updateReportRun = asyncHandler(async (req, res) => {
  const result = await reportRunService.updateReportRun(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.report_run.update_success', result);
});

const deleteReportRun = asyncHandler(async (req, res) => {
  await reportRunService.deleteReportRun(req.params.id, buildContext(req));
  sendNoContent(res);
});

const retryReportRun = asyncHandler(async (req, res) => {
  const result = await reportRunService.retryReportRun(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.report_run.create_success', result);
});

const cancelReportRun = asyncHandler(async (req, res) => {
  const result = await reportRunService.cancelReportRunById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.report_run.update_success', result);
});

const downloadReportRun = asyncHandler(async (req, res) => {
  const result = await reportRunService.downloadReportRun(req.params.id, buildContext(req));
  res.setHeader('Content-Type', result.mime_type);
  res.setHeader('Content-Disposition', `attachment; filename="${result.file_name}"`);
  res.status(200).send(result.buffer);
});

module.exports = {
  cancelReportRun,
  createReportRun,
  deleteReportRun,
  downloadReportRun,
  getReportRunById,
  listReportRuns,
  retryReportRun,
  updateReportRun,
};
