const equipmentLocationHistoryService = require('@services/equipment-location-history/equipment-location-history.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentLocationHistorys = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentLocationHistoryService.listEquipmentLocationHistorys(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_location_history.list.success', result.equipmentLocationHistories, result.pagination);
});

const getEquipmentLocationHistoryById = asyncHandler(async (req, res) => {
  const item = await equipmentLocationHistoryService.getEquipmentLocationHistoryById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_location_history.get.success', item);
});

const createEquipmentLocationHistory = asyncHandler(async (req, res) => {
  const item = await equipmentLocationHistoryService.createEquipmentLocationHistory(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_location_history.create.success', item);
});

const updateEquipmentLocationHistory = asyncHandler(async (req, res) => {
  const item = await equipmentLocationHistoryService.updateEquipmentLocationHistory(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_location_history.update.success', item);
});

const deleteEquipmentLocationHistory = asyncHandler(async (req, res) => {
  await equipmentLocationHistoryService.deleteEquipmentLocationHistory(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentLocationHistorys, getEquipmentLocationHistoryById, createEquipmentLocationHistory, updateEquipmentLocationHistory, deleteEquipmentLocationHistory };
