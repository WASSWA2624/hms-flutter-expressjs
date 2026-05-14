const closeoutPackService = require('@services/closeout-pack/closeout-pack.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');
const { buildContext } = require('@lib/last-office/shared');

const listCloseoutPacks = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await closeoutPackService.listCloseoutPacks(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.closeout_pack.list_success', result.closeoutPacks, result.pagination);
});

const getCloseoutPackById = asyncHandler(async (req, res) => {
  const result = await closeoutPackService.getCloseoutPackById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.closeout_pack.get_success', result);
});

const createCloseoutPack = asyncHandler(async (req, res) => {
  const result = await closeoutPackService.createCloseoutPack(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.closeout_pack.create_success', result);
});

const downloadCloseoutPack = asyncHandler(async (req, res) => {
  const result = await closeoutPackService.downloadCloseoutPack(req.params.id, buildContext(req));
  res.setHeader('Content-Type', result.mime_type);
  res.setHeader('Content-Disposition', `attachment; filename="${result.file_name}"`);
  res.status(200).send(result.buffer);
});

module.exports = {
  createCloseoutPack,
  downloadCloseoutPack,
  getCloseoutPackById,
  listCloseoutPacks,
};
