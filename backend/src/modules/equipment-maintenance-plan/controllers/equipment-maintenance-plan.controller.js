const equipmentMaintenancePlanService = require('@services/equipment-maintenance-plan/equipment-maintenance-plan.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentMaintenancePlans = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentMaintenancePlanService.listEquipmentMaintenancePlans(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_maintenance_plan.list.success', result.equipmentMaintenancePlans, result.pagination);
});

const getEquipmentMaintenancePlanById = asyncHandler(async (req, res) => {
  const item = await equipmentMaintenancePlanService.getEquipmentMaintenancePlanById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_maintenance_plan.get.success', item);
});

const createEquipmentMaintenancePlan = asyncHandler(async (req, res) => {
  const item = await equipmentMaintenancePlanService.createEquipmentMaintenancePlan(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_maintenance_plan.create.success', item);
});

const updateEquipmentMaintenancePlan = asyncHandler(async (req, res) => {
  const item = await equipmentMaintenancePlanService.updateEquipmentMaintenancePlan(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_maintenance_plan.update.success', item);
});

const deleteEquipmentMaintenancePlan = asyncHandler(async (req, res) => {
  await equipmentMaintenancePlanService.deleteEquipmentMaintenancePlan(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentMaintenancePlans, getEquipmentMaintenancePlanById, createEquipmentMaintenancePlan, updateEquipmentMaintenancePlan, deleteEquipmentMaintenancePlan };
