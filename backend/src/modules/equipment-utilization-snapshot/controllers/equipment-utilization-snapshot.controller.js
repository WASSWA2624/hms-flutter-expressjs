const equipmentUtilizationSnapshotService = require('@services/equipment-utilization-snapshot/equipment-utilization-snapshot.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentUtilizationSnapshots = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentUtilizationSnapshotService.listEquipmentUtilizationSnapshots(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_utilization_snapshot.list.success', result.equipmentUtilizationSnapshots, result.pagination);
});

const getEquipmentUtilizationSnapshotById = asyncHandler(async (req, res) => {
  const item = await equipmentUtilizationSnapshotService.getEquipmentUtilizationSnapshotById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_utilization_snapshot.get.success', item);
});

const createEquipmentUtilizationSnapshot = asyncHandler(async (req, res) => {
  const item = await equipmentUtilizationSnapshotService.createEquipmentUtilizationSnapshot(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_utilization_snapshot.create.success', item);
});

const updateEquipmentUtilizationSnapshot = asyncHandler(async (req, res) => {
  const item = await equipmentUtilizationSnapshotService.updateEquipmentUtilizationSnapshot(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_utilization_snapshot.update.success', item);
});

const deleteEquipmentUtilizationSnapshot = asyncHandler(async (req, res) => {
  await equipmentUtilizationSnapshotService.deleteEquipmentUtilizationSnapshot(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentUtilizationSnapshots, getEquipmentUtilizationSnapshotById, createEquipmentUtilizationSnapshot, updateEquipmentUtilizationSnapshot, deleteEquipmentUtilizationSnapshot };
