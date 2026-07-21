const custodySnapshotService = require('@services/custody-snapshot/custody-snapshot.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');
const { buildContext } = require('@lib/last-office/shared');

const listCustodySnapshots = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await custodySnapshotService.listCustodySnapshots(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.custody_snapshot.list_success', result.custodySnapshots, result.pagination);
});

const getCustodySnapshotById = asyncHandler(async (req, res) => {
  const result = await custodySnapshotService.getCustodySnapshotById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.custody_snapshot.get_success', result);
});

const createCustodySnapshot = asyncHandler(async (req, res) => {
  const result = await custodySnapshotService.createCustodySnapshot(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.custody_snapshot.create_success', result);
});

const updateCustodySnapshot = asyncHandler(async (req, res) => {
  const result = await custodySnapshotService.updateCustodySnapshot(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.custody_snapshot.update_success', result);
});

const finalizeCustodySnapshot = asyncHandler(async (req, res) => {
  const result = await custodySnapshotService.finalizeCustodySnapshot(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.custody_snapshot.update_success', result);
});

module.exports = {
  createCustodySnapshot,
  finalizeCustodySnapshot,
  getCustodySnapshotById,
  listCustodySnapshots,
  updateCustodySnapshot,
};
