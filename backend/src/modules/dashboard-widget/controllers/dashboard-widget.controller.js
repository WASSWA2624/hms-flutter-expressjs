const dashboardWidgetService = require('@services/dashboard-widget/dashboard-widget.service');
const { asyncHandler } = require('@lib/async');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listDashboardWidgets = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await dashboardWidgetService.listDashboardWidgets(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.dashboard_widget.list.success', result.dashboardWidgets, result.pagination);
});

const getDashboardWidgetById = asyncHandler(async (req, res) => {
  const widget = await dashboardWidgetService.getDashboardWidgetById(req.params.id, req.user);
  sendSuccess(res, 200, 'messages.dashboard_widget.get.success', widget);
});

const createDashboardWidget = asyncHandler(async (req, res) => {
  const widget = await dashboardWidgetService.createDashboardWidget(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.dashboard_widget.create.success', widget);
});

const updateDashboardWidget = asyncHandler(async (req, res) => {
  const widget = await dashboardWidgetService.updateDashboardWidget(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.dashboard_widget.update.success', widget);
});

const deleteDashboardWidget = asyncHandler(async (req, res) => {
  await dashboardWidgetService.deleteDashboardWidget(req.params.id, buildContext(req));
  sendNoContent(res);
});

const getDashboardSummary = asyncHandler(async (req, res) => {
  const summary = await dashboardWidgetService.getDashboardSummary(req.query, req.user);
  sendSuccess(res, 200, 'messages.dashboard_widget.get.success', summary);
});

module.exports = {
  createDashboardWidget,
  deleteDashboardWidget,
  getDashboardSummary,
  getDashboardWidgetById,
  listDashboardWidgets,
  updateDashboardWidget,
};
