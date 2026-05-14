/**
 * Purchase order controller
 */

const purchaseOrderService = require('@services/purchase-order/purchase-order.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendCreated, sendNoContent } = require('@lib/response');

const getPurchaseOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const purchaseOrder = await purchaseOrderService.getPurchaseOrderById(id);
  sendSuccess(res, purchaseOrder, 'messages.purchase_order.retrieved', req.locale);
});

const listPurchaseOrders = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  const result = await purchaseOrderService.listPurchaseOrders(
    filters,
    { page: parseInt(page) || 1, limit: parseInt(limit) || 20 },
    { sort_by, order }
  );
  sendSuccess(res, result.data, 'messages.purchase_order.list_retrieved', req.locale, {
    pagination: {
      page: result.page,
      limit: result.limit,
      total: result.total,
      total_pages: Math.ceil(result.total / result.limit)
    }
  });
});

const createPurchaseOrder = asyncHandler(async (req, res) => {
  const purchaseOrderData = req.body;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  const purchaseOrder = await purchaseOrderService.createPurchaseOrder(purchaseOrderData, auditContext);
  sendCreated(res, purchaseOrder, 'messages.purchase_order.created', req.locale);
});

const updatePurchaseOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateData = req.body;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  const purchaseOrder = await purchaseOrderService.updatePurchaseOrder(id, updateData, auditContext);
  sendSuccess(res, purchaseOrder, 'messages.purchase_order.updated', req.locale);
});

const deletePurchaseOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  await purchaseOrderService.deletePurchaseOrder(id, auditContext);
  sendNoContent(res);
});

module.exports = {
  getPurchaseOrder,
  listPurchaseOrders,
  createPurchaseOrder,
  updatePurchaseOrder,
  deletePurchaseOrder
};
