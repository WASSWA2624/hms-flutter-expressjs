const equipmentWorkOrderService = require('@services/equipment-work-order/equipment-work-order.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listEquipmentWorkOrders = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const result = await equipmentWorkOrderService.listEquipmentWorkOrders(filters, parseInt(page, 10), parseInt(limit, 10), sort_by || 'created_at', order);
  sendPaginated(res, 'messages.equipment_work_order.list.success', result.equipmentWorkOrders, result.pagination);
});

const getEquipmentWorkOrderById = asyncHandler(async (req, res) => {
  const item = await equipmentWorkOrderService.getEquipmentWorkOrderById(req.params.id);
  sendSuccess(res, 200, 'messages.equipment_work_order.get.success', item);
});

const createEquipmentWorkOrder = asyncHandler(async (req, res) => {
  const item = await equipmentWorkOrderService.createEquipmentWorkOrder(req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 201, 'messages.equipment_work_order.create.success', item);
});

const updateEquipmentWorkOrder = asyncHandler(async (req, res) => {
  const item = await equipmentWorkOrderService.updateEquipmentWorkOrder(req.params.id, req.body, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendSuccess(res, 200, 'messages.equipment_work_order.update.success', item);
});

const deleteEquipmentWorkOrder = asyncHandler(async (req, res) => {
  await equipmentWorkOrderService.deleteEquipmentWorkOrder(req.params.id, { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip });
  sendNoContent(res);
});

const startEquipmentWorkOrder = asyncHandler(async (req, res) => {
  const item = await equipmentWorkOrderService.startEquipmentWorkOrder(
    req.params.id,
    req.body,
    { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip }
  );
  sendSuccess(res, 200, 'messages.equipment_work_order.start.success', item);
});

const returnToServiceEquipmentWorkOrder = asyncHandler(async (req, res) => {
  const item = await equipmentWorkOrderService.returnToServiceEquipmentWorkOrder(
    req.params.id,
    req.body,
    { user_id: req.user?.id, tenant_id: req.user?.tenant_id, ip_address: req.ip }
  );
  sendSuccess(res, 200, 'messages.equipment_work_order.return_to_service.success', item);
});

module.exports = {
  listEquipmentWorkOrders,
  getEquipmentWorkOrderById,
  createEquipmentWorkOrder,
  updateEquipmentWorkOrder,
  deleteEquipmentWorkOrder,
  startEquipmentWorkOrder,
  returnToServiceEquipmentWorkOrder
};
