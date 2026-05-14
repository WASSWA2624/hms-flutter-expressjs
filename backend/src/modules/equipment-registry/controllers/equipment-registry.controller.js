const equipmentRegistryService = require('@services/equipment-registry/equipment-registry.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentRegistrys = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentRegistryService.listEquipmentRegistrys(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_registry.list.success', result.equipmentRegistries, result.pagination);
});

const getEquipmentRegistryById = asyncHandler(async (req, res) => {
  const item = await equipmentRegistryService.getEquipmentRegistryById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_registry.get.success', item);
});

const createEquipmentRegistry = asyncHandler(async (req, res) => {
  const item = await equipmentRegistryService.createEquipmentRegistry(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_registry.create.success', item);
});

const updateEquipmentRegistry = asyncHandler(async (req, res) => {
  const item = await equipmentRegistryService.updateEquipmentRegistry(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_registry.update.success', item);
});

const deleteEquipmentRegistry = asyncHandler(async (req, res) => {
  await equipmentRegistryService.deleteEquipmentRegistry(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentRegistrys, getEquipmentRegistryById, createEquipmentRegistry, updateEquipmentRegistry, deleteEquipmentRegistry };
