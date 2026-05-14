const equipmentDowntimeLogService = require('@services/equipment-downtime-log/equipment-downtime-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentDowntimeLogs = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentDowntimeLogService.listEquipmentDowntimeLogs(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_downtime_log.list.success', result.equipmentDowntimeLogs, result.pagination);
});

const getEquipmentDowntimeLogById = asyncHandler(async (req, res) => {
  const item = await equipmentDowntimeLogService.getEquipmentDowntimeLogById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_downtime_log.get.success', item);
});

const createEquipmentDowntimeLog = asyncHandler(async (req, res) => {
  const item = await equipmentDowntimeLogService.createEquipmentDowntimeLog(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_downtime_log.create.success', item);
});

const updateEquipmentDowntimeLog = asyncHandler(async (req, res) => {
  const item = await equipmentDowntimeLogService.updateEquipmentDowntimeLog(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_downtime_log.update.success', item);
});

const deleteEquipmentDowntimeLog = asyncHandler(async (req, res) => {
  await equipmentDowntimeLogService.deleteEquipmentDowntimeLog(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentDowntimeLogs, getEquipmentDowntimeLogById, createEquipmentDowntimeLog, updateEquipmentDowntimeLog, deleteEquipmentDowntimeLog };
