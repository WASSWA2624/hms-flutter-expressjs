const analyticsEventService = require('@services/analytics-event/analytics-event.service');
const { asyncHandler } = require('@lib/async');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listAnalyticsEvents = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await analyticsEventService.listAnalyticsEvents(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.analytics_event.list.success', result.analyticsEvents, result.pagination);
});

const getAnalyticsEventById = asyncHandler(async (req, res) => {
  const result = await analyticsEventService.getAnalyticsEventById(req.params.id, req.user);
  sendSuccess(res, 200, 'messages.analytics_event.get.success', result);
});

const createAnalyticsEvent = asyncHandler(async (req, res) => {
  const result = await analyticsEventService.createAnalyticsEvent(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.analytics_event.create.success', result);
});

const updateAnalyticsEvent = asyncHandler(async (req, res) => {
  const result = await analyticsEventService.updateAnalyticsEvent(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.analytics_event.update.success', result);
});

const deleteAnalyticsEvent = asyncHandler(async (req, res) => {
  await analyticsEventService.deleteAnalyticsEvent(req.params.id, buildContext(req));
  sendNoContent(res);
});

module.exports = {
  createAnalyticsEvent,
  deleteAnalyticsEvent,
  getAnalyticsEventById,
  listAnalyticsEvents,
  updateAnalyticsEvent,
};
