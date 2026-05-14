const equipmentSparePartService = require('@services/equipment-spare-part/equipment-spare-part.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentSpareParts = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentSparePartService.listEquipmentSpareParts(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_spare_part.list.success', result.equipmentSpareParts, result.pagination);
});

const getEquipmentSparePartById = asyncHandler(async (req, res) => {
  const item = await equipmentSparePartService.getEquipmentSparePartById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_spare_part.get.success', item);
});

const createEquipmentSparePart = asyncHandler(async (req, res) => {
  const item = await equipmentSparePartService.createEquipmentSparePart(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_spare_part.create.success', item);
});

const updateEquipmentSparePart = asyncHandler(async (req, res) => {
  const item = await equipmentSparePartService.updateEquipmentSparePart(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_spare_part.update.success', item);
});

const deleteEquipmentSparePart = asyncHandler(async (req, res) => {
  await equipmentSparePartService.deleteEquipmentSparePart(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentSpareParts, getEquipmentSparePartById, createEquipmentSparePart, updateEquipmentSparePart, deleteEquipmentSparePart };
