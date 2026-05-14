const equipmentDisposalTransferService = require('@services/equipment-disposal-transfer/equipment-disposal-transfer.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentDisposalTransfers = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentDisposalTransferService.listEquipmentDisposalTransfers(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_disposal_transfer.list.success', result.equipmentDisposalTransfers, result.pagination);
});

const getEquipmentDisposalTransferById = asyncHandler(async (req, res) => {
  const item = await equipmentDisposalTransferService.getEquipmentDisposalTransferById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_disposal_transfer.get.success', item);
});

const createEquipmentDisposalTransfer = asyncHandler(async (req, res) => {
  const item = await equipmentDisposalTransferService.createEquipmentDisposalTransfer(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_disposal_transfer.create.success', item);
});

const updateEquipmentDisposalTransfer = asyncHandler(async (req, res) => {
  const item = await equipmentDisposalTransferService.updateEquipmentDisposalTransfer(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_disposal_transfer.update.success', item);
});

const deleteEquipmentDisposalTransfer = asyncHandler(async (req, res) => {
  await equipmentDisposalTransferService.deleteEquipmentDisposalTransfer(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentDisposalTransfers, getEquipmentDisposalTransferById, createEquipmentDisposalTransfer, updateEquipmentDisposalTransfer, deleteEquipmentDisposalTransfer };
