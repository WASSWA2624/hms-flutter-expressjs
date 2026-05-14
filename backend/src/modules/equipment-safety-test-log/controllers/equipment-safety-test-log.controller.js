const equipmentSafetyTestLogService = require('@services/equipment-safety-test-log/equipment-safety-test-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentSafetyTestLogs = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentSafetyTestLogService.listEquipmentSafetyTestLogs(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_safety_test_log.list.success', result.equipmentSafetyTestLogs, result.pagination);
});

const getEquipmentSafetyTestLogById = asyncHandler(async (req, res) => {
  const item = await equipmentSafetyTestLogService.getEquipmentSafetyTestLogById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_safety_test_log.get.success', item);
});

const createEquipmentSafetyTestLog = asyncHandler(async (req, res) => {
  const item = await equipmentSafetyTestLogService.createEquipmentSafetyTestLog(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_safety_test_log.create.success', item);
});

const updateEquipmentSafetyTestLog = asyncHandler(async (req, res) => {
  const item = await equipmentSafetyTestLogService.updateEquipmentSafetyTestLog(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_safety_test_log.update.success', item);
});

const deleteEquipmentSafetyTestLog = asyncHandler(async (req, res) => {
  await equipmentSafetyTestLogService.deleteEquipmentSafetyTestLog(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentSafetyTestLogs, getEquipmentSafetyTestLogById, createEquipmentSafetyTestLog, updateEquipmentSafetyTestLog, deleteEquipmentSafetyTestLog };
