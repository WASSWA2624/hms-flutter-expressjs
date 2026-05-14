const kpiSnapshotService = require('@services/kpi-snapshot/kpi-snapshot.service');
const { asyncHandler } = require('@lib/async');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  ip_address: req.ip,
  user_agent: req.get('user-agent'),
});

const listKpiSnapshots = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await kpiSnapshotService.listKpiSnapshots(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.kpi_snapshot.list.success', result.kpiSnapshots, result.pagination);
});

const getKpiSnapshotById = asyncHandler(async (req, res) => {
  const result = await kpiSnapshotService.getKpiSnapshotById(req.params.id, req.user);
  sendSuccess(res, 200, 'messages.kpi_snapshot.get.success', result);
});

const createKpiSnapshot = asyncHandler(async (req, res) => {
  const result = await kpiSnapshotService.createKpiSnapshot(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.kpi_snapshot.create.success', result);
});

const updateKpiSnapshot = asyncHandler(async (req, res) => {
  const result = await kpiSnapshotService.updateKpiSnapshot(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.kpi_snapshot.update.success', result);
});

const deleteKpiSnapshot = asyncHandler(async (req, res) => {
  await kpiSnapshotService.deleteKpiSnapshot(req.params.id, buildContext(req));
  sendNoContent(res);
});

module.exports = {
  createKpiSnapshot,
  deleteKpiSnapshot,
  getKpiSnapshotById,
  listKpiSnapshots,
  updateKpiSnapshot,
};
