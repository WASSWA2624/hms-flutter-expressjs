/**
 * Purchase order service
 */

const purchaseOrderRepository = require('@repositories/purchase-order/purchase-order.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const getPurchaseOrderById = async (id) => {
  const purchaseOrder = await purchaseOrderRepository.findById(id);
  if (!purchaseOrder) {
    throw new HttpError('errors.purchase_order.not_found', 404);
  }
  return purchaseOrder;
};

const listPurchaseOrders = async (filters, pagination, sort) => {
  const { page = 1, limit = 20 } = pagination;
  const { sort_by = 'created_at', order = 'desc' } = sort;
  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };
  
  const whereFilters = {};
  if (filters.purchase_request_id) whereFilters.purchase_request_id = filters.purchase_request_id;
  if (filters.supplier_id) whereFilters.supplier_id = filters.supplier_id;
  if (filters.status) whereFilters.status = filters.status;
  if (filters.search) {
    whereFilters.OR = [{ status: { contains: filters.search } }];
  }
  
  const [data, total] = await Promise.all([
    purchaseOrderRepository.findMany(whereFilters, skip, limit, orderBy),
    purchaseOrderRepository.count(whereFilters)
  ]);
  
  return { data, total, page, limit };
};

const createPurchaseOrder = async (purchaseOrderData, auditContext) => {
  const purchaseOrder = await purchaseOrderRepository.create(purchaseOrderData);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'purchase_order',
    entity_id: purchaseOrder.id,
    diff: { after: purchaseOrder },
    ip_address: auditContext.ip_address
  });
  return purchaseOrder;
};

const updatePurchaseOrder = async (id, updateData, auditContext) => {
  const existingPurchaseOrder = await purchaseOrderRepository.findById(id);
  if (!existingPurchaseOrder) {
    throw new HttpError('errors.purchase_order.not_found', 404);
  }
  const updatedPurchaseOrder = await purchaseOrderRepository.update(id, updateData);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'purchase_order',
    entity_id: id,
    diff: { before: existingPurchaseOrder, after: updatedPurchaseOrder },
    ip_address: auditContext.ip_address
  });
  return updatedPurchaseOrder;
};

const deletePurchaseOrder = async (id, auditContext) => {
  const existingPurchaseOrder = await purchaseOrderRepository.findById(id);
  if (!existingPurchaseOrder) {
    throw new HttpError('errors.purchase_order.not_found', 404);
  }
  const deletedPurchaseOrder = await purchaseOrderRepository.softDelete(id);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'purchase_order',
    entity_id: id,
    diff: { before: existingPurchaseOrder },
    ip_address: auditContext.ip_address
  });
  return deletedPurchaseOrder;
};

module.exports = {
  getPurchaseOrderById,
  listPurchaseOrders,
  createPurchaseOrder,
  updatePurchaseOrder,
  deletePurchaseOrder
};
