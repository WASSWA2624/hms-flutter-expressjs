const equipmentCategoryService = require('@services/equipment-category/equipment-category.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentCategorys = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentCategoryService.listEquipmentCategorys(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_category.list.success', result.equipmentCategories, result.pagination);
});

const getEquipmentCategoryById = asyncHandler(async (req, res) => {
  const item = await equipmentCategoryService.getEquipmentCategoryById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_category.get.success', item);
});

const createEquipmentCategory = asyncHandler(async (req, res) => {
  const item = await equipmentCategoryService.createEquipmentCategory(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_category.create.success', item);
});

const updateEquipmentCategory = asyncHandler(async (req, res) => {
  const item = await equipmentCategoryService.updateEquipmentCategory(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_category.update.success', item);
});

const deleteEquipmentCategory = asyncHandler(async (req, res) => {
  await equipmentCategoryService.deleteEquipmentCategory(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentCategorys, getEquipmentCategoryById, createEquipmentCategory, updateEquipmentCategory, deleteEquipmentCategory };
