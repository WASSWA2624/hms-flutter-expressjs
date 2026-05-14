const equipmentServiceProviderService = require('@services/equipment-service-provider/equipment-service-provider.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentServiceProviders = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentServiceProviderService.listEquipmentServiceProviders(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_service_provider.list.success', result.equipmentServiceProviders, result.pagination);
});

const getEquipmentServiceProviderById = asyncHandler(async (req, res) => {
  const item = await equipmentServiceProviderService.getEquipmentServiceProviderById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_service_provider.get.success', item);
});

const createEquipmentServiceProvider = asyncHandler(async (req, res) => {
  const item = await equipmentServiceProviderService.createEquipmentServiceProvider(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_service_provider.create.success', item);
});

const updateEquipmentServiceProvider = asyncHandler(async (req, res) => {
  const item = await equipmentServiceProviderService.updateEquipmentServiceProvider(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_service_provider.update.success', item);
});

const deleteEquipmentServiceProvider = asyncHandler(async (req, res) => {
  await equipmentServiceProviderService.deleteEquipmentServiceProvider(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentServiceProviders, getEquipmentServiceProviderById, createEquipmentServiceProvider, updateEquipmentServiceProvider, deleteEquipmentServiceProvider };
