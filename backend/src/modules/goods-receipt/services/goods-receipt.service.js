/**
 * Goods receipt service
 */

const goodsReceiptRepository = require('@repositories/goods-receipt/goods-receipt.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const getGoodsReceiptById = async (id) => {
  const goodsReceipt = await goodsReceiptRepository.findById(id);
  if (!goodsReceipt) {
    throw new HttpError('errors.goods_receipt.not_found', 404);
  }
  return goodsReceipt;
};

const listGoodsReceipts = async (filters, pagination, sort) => {
  const { page = 1, limit = 20 } = pagination;
  const { sort_by = 'created_at', order = 'desc' } = sort;
  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };
  
  const whereFilters = {};
  if (filters.purchase_order_id) whereFilters.purchase_order_id = filters.purchase_order_id;
  if (filters.status) whereFilters.status = filters.status;
  if (filters.search) {
    whereFilters.OR = [{ status: { contains: filters.search } }];
  }
  
  const [data, total] = await Promise.all([
    goodsReceiptRepository.findMany(whereFilters, skip, limit, orderBy),
    goodsReceiptRepository.count(whereFilters)
  ]);
  
  return { data, total, page, limit };
};

const createGoodsReceipt = async (goodsReceiptData, auditContext) => {
  const goodsReceipt = await goodsReceiptRepository.create(goodsReceiptData);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'goods_receipt',
    entity_id: goodsReceipt.id,
    diff: { after: goodsReceipt },
    ip_address: auditContext.ip_address
  });
  return goodsReceipt;
};

const updateGoodsReceipt = async (id, updateData, auditContext) => {
  const existingGoodsReceipt = await goodsReceiptRepository.findById(id);
  if (!existingGoodsReceipt) {
    throw new HttpError('errors.goods_receipt.not_found', 404);
  }
  const updatedGoodsReceipt = await goodsReceiptRepository.update(id, updateData);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'goods_receipt',
    entity_id: id,
    diff: { before: existingGoodsReceipt, after: updatedGoodsReceipt },
    ip_address: auditContext.ip_address
  });
  return updatedGoodsReceipt;
};

const deleteGoodsReceipt = async (id, auditContext) => {
  const existingGoodsReceipt = await goodsReceiptRepository.findById(id);
  if (!existingGoodsReceipt) {
    throw new HttpError('errors.goods_receipt.not_found', 404);
  }
  const deletedGoodsReceipt = await goodsReceiptRepository.softDelete(id);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'goods_receipt',
    entity_id: id,
    diff: { before: existingGoodsReceipt },
    ip_address: auditContext.ip_address
  });
  return deletedGoodsReceipt;
};

module.exports = {
  getGoodsReceiptById,
  listGoodsReceipts,
  createGoodsReceipt,
  updateGoodsReceipt,
  deleteGoodsReceipt
};
