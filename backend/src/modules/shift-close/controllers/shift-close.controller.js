const shiftCloseService = require('@services/shift-close/shift-close.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');
const { buildContext } = require('@lib/last-office/shared');

const listShiftCloses = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await shiftCloseService.listShiftCloses(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.shift_close.list_success', result.shiftCloses, result.pagination);
});

const getShiftCloseById = asyncHandler(async (req, res) => {
  const result = await shiftCloseService.getShiftCloseById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.shift_close.get_success', result);
});

const createShiftClose = asyncHandler(async (req, res) => {
  const result = await shiftCloseService.createShiftClose(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.shift_close.create_success', result);
});

const updateShiftClose = asyncHandler(async (req, res) => {
  const result = await shiftCloseService.updateShiftClose(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.shift_close.update_success', result);
});

const approveShiftClose = asyncHandler(async (req, res) => {
  const result = await shiftCloseService.approveShiftClose(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.shift_close.update_success', result);
});

module.exports = {
  approveShiftClose,
  createShiftClose,
  getShiftCloseById,
  listShiftCloses,
  updateShiftClose,
};
