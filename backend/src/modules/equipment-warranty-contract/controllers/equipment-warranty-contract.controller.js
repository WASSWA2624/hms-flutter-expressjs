const equipmentWarrantyContractService = require('@services/equipment-warranty-contract/equipment-warranty-contract.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentWarrantyContracts = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentWarrantyContractService.listEquipmentWarrantyContracts(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_warranty_contract.list.success', result.equipmentWarrantyContracts, result.pagination);
});

const getEquipmentWarrantyContractById = asyncHandler(async (req, res) => {
  const item = await equipmentWarrantyContractService.getEquipmentWarrantyContractById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_warranty_contract.get.success', item);
});

const createEquipmentWarrantyContract = asyncHandler(async (req, res) => {
  const item = await equipmentWarrantyContractService.createEquipmentWarrantyContract(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_warranty_contract.create.success', item);
});

const updateEquipmentWarrantyContract = asyncHandler(async (req, res) => {
  const item = await equipmentWarrantyContractService.updateEquipmentWarrantyContract(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_warranty_contract.update.success', item);
});

const deleteEquipmentWarrantyContract = asyncHandler(async (req, res) => {
  await equipmentWarrantyContractService.deleteEquipmentWarrantyContract(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentWarrantyContracts, getEquipmentWarrantyContractById, createEquipmentWarrantyContract, updateEquipmentWarrantyContract, deleteEquipmentWarrantyContract };
