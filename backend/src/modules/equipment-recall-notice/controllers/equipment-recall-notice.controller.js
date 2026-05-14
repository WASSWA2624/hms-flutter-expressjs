const equipmentRecallNoticeService = require('@services/equipment-recall-notice/equipment-recall-notice.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentRecallNotices = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentRecallNoticeService.listEquipmentRecallNotices(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_recall_notice.list.success', result.equipmentRecallNotices, result.pagination);
});

const getEquipmentRecallNoticeById = asyncHandler(async (req, res) => {
  const item = await equipmentRecallNoticeService.getEquipmentRecallNoticeById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_recall_notice.get.success', item);
});

const createEquipmentRecallNotice = asyncHandler(async (req, res) => {
  const item = await equipmentRecallNoticeService.createEquipmentRecallNotice(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_recall_notice.create.success', item);
});

const updateEquipmentRecallNotice = asyncHandler(async (req, res) => {
  const item = await equipmentRecallNoticeService.updateEquipmentRecallNotice(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_recall_notice.update.success', item);
});

const deleteEquipmentRecallNotice = asyncHandler(async (req, res) => {
  await equipmentRecallNoticeService.deleteEquipmentRecallNotice(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

module.exports = { listEquipmentRecallNotices, getEquipmentRecallNoticeById, createEquipmentRecallNotice, updateEquipmentRecallNotice, deleteEquipmentRecallNotice };
