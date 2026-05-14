const equipmentCalibrationLogService = require('@services/equipment-calibration-log/equipment-calibration-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentCalibrationLogs = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentCalibrationLogService.listEquipmentCalibrationLogs(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_calibration_log.list.success', result.equipmentCalibrationLogs, result.pagination);
});

const getEquipmentCalibrationLogById = asyncHandler(async (req, res) => {
  const item = await equipmentCalibrationLogService.getEquipmentCalibrationLogById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_calibration_log.get.success', item);
});

const createEquipmentCalibrationLog = asyncHandler(async (req, res) => {
  const item = await equipmentCalibrationLogService.createEquipmentCalibrationLog(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_calibration_log.create.success', item);
});

const updateEquipmentCalibrationLog = asyncHandler(async (req, res) => {
  const item = await equipmentCalibrationLogService.updateEquipmentCalibrationLog(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_calibration_log.update.success', item);
});

const deleteEquipmentCalibrationLog = asyncHandler(async (req, res) => {
  await equipmentCalibrationLogService.deleteEquipmentCalibrationLog(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentCalibrationLogs, getEquipmentCalibrationLogById, createEquipmentCalibrationLog, updateEquipmentCalibrationLog, deleteEquipmentCalibrationLog };
