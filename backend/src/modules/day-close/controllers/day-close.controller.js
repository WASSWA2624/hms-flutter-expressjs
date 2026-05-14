const dayCloseService = require('@services/day-close/day-close.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');
const { buildContext } = require('@lib/last-office/shared');

const listDayCloses = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await dayCloseService.listDayCloses(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.day_close.list_success', result.dayCloses, result.pagination);
});

const getDayCloseById = asyncHandler(async (req, res) => {
  const result = await dayCloseService.getDayCloseById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.day_close.get_success', result);
});

const createDayClose = asyncHandler(async (req, res) => {
  const result = await dayCloseService.createDayClose(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.day_close.create_success', result);
});

const updateDayClose = asyncHandler(async (req, res) => {
  const result = await dayCloseService.updateDayClose(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.day_close.update_success', result);
});

const approveDayClose = asyncHandler(async (req, res) => {
  const result = await dayCloseService.approveDayClose(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.day_close.update_success', result);
});

module.exports = {
  approveDayClose,
  createDayClose,
  getDayCloseById,
  listDayCloses,
  updateDayClose,
};
