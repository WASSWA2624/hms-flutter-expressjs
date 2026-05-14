const reportScheduleService = require('@services/report-schedule/report-schedule.service');
const { asyncHandler } = require('@lib/async');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listReportSchedules = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await reportScheduleService.listReportSchedules(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  sendPaginated(res, 'messages.report_schedule.list_success', result.reportSchedules, result.pagination);
});

const getReportScheduleById = asyncHandler(async (req, res) => {
  const result = await reportScheduleService.getReportScheduleById(req.params.id, req.user);
  sendSuccess(res, 200, 'messages.report_schedule.get_success', result);
});

const createReportSchedule = asyncHandler(async (req, res) => {
  const result = await reportScheduleService.createReportSchedule(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.report_schedule.create_success', result);
});

const updateReportSchedule = asyncHandler(async (req, res) => {
  const result = await reportScheduleService.updateReportSchedule(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.report_schedule.update_success', result);
});

const pauseReportSchedule = asyncHandler(async (req, res) => {
  const result = await reportScheduleService.pauseReportSchedule(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.report_schedule.update_success', result);
});

const resumeReportSchedule = asyncHandler(async (req, res) => {
  const result = await reportScheduleService.resumeReportSchedule(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.report_schedule.update_success', result);
});

const deleteReportSchedule = asyncHandler(async (req, res) => {
  await reportScheduleService.deleteReportSchedule(req.params.id, buildContext(req));
  sendNoContent(res);
});

module.exports = {
  createReportSchedule,
  deleteReportSchedule,
  getReportScheduleById,
  listReportSchedules,
  pauseReportSchedule,
  resumeReportSchedule,
  updateReportSchedule,
};
