const handoverService = require('@services/handover/handover.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');
const { buildContext } = require('@lib/last-office/shared');

const listHandovers = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await handoverService.listHandovers(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.handover.list_success', result.handovers, result.pagination);
});

const getHandoverById = asyncHandler(async (req, res) => {
  const result = await handoverService.getHandoverById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.handover.get_success', result);
});

const createHandover = asyncHandler(async (req, res) => {
  const result = await handoverService.createHandover(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.handover.create_success', result);
});

const updateHandover = asyncHandler(async (req, res) => {
  const result = await handoverService.updateHandover(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.handover.update_success', result);
});

const acceptHandover = asyncHandler(async (req, res) => {
  const result = await handoverService.acceptHandover(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.handover.update_success', result);
});

module.exports = {
  acceptHandover,
  createHandover,
  getHandoverById,
  listHandovers,
  updateHandover,
};
