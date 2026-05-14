/**
 * Stock adjustment service
 */

const stockAdjustmentRepository = require('@repositories/stock-adjustment/stock-adjustment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const getStockAdjustmentById = async (id) => {
  const stockAdjustment = await stockAdjustmentRepository.findById(id);
  if (!stockAdjustment) {
    throw new HttpError('errors.stock_adjustment.not_found', 404);
  }
  return stockAdjustment;
};

const listStockAdjustments = async (filters, pagination, sort) => {
  const { page = 1, limit = 20 } = pagination;
  const { sort_by = 'created_at', order = 'desc' } = sort;
  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };
  
  const whereFilters = {};
  if (filters.inventory_item_id) whereFilters.inventory_item_id = filters.inventory_item_id;
  if (filters.facility_id) whereFilters.facility_id = filters.facility_id;
  if (filters.reason) whereFilters.reason = filters.reason;
  if (filters.search) {
    whereFilters.OR = [{ reason: { contains: filters.search } }];
  }
  
  const [data, total] = await Promise.all([
    stockAdjustmentRepository.findMany(whereFilters, skip, limit, orderBy),
    stockAdjustmentRepository.count(whereFilters)
  ]);
  
  return { data, total, page, limit };
};

const createStockAdjustment = async (stockAdjustmentData, auditContext) => {
  const stockAdjustment = await stockAdjustmentRepository.create(stockAdjustmentData);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'stock_adjustment',
    entity_id: stockAdjustment.id,
    diff: { after: stockAdjustment },
    ip_address: auditContext.ip_address
  });
  return stockAdjustment;
};

const updateStockAdjustment = async (id, updateData, auditContext) => {
  const existingStockAdjustment = await stockAdjustmentRepository.findById(id);
  if (!existingStockAdjustment) {
    throw new HttpError('errors.stock_adjustment.not_found', 404);
  }
  const updatedStockAdjustment = await stockAdjustmentRepository.update(id, updateData);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'stock_adjustment',
    entity_id: id,
    diff: { before: existingStockAdjustment, after: updatedStockAdjustment },
    ip_address: auditContext.ip_address
  });
  return updatedStockAdjustment;
};

const deleteStockAdjustment = async (id, auditContext) => {
  const existingStockAdjustment = await stockAdjustmentRepository.findById(id);
  if (!existingStockAdjustment) {
    throw new HttpError('errors.stock_adjustment.not_found', 404);
  }
  const deletedStockAdjustment = await stockAdjustmentRepository.softDelete(id);
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'stock_adjustment',
    entity_id: id,
    diff: { before: existingStockAdjustment },
    ip_address: auditContext.ip_address
  });
  return deletedStockAdjustment;
};

module.exports = {
  getStockAdjustmentById,
  listStockAdjustments,
  createStockAdjustment,
  updateStockAdjustment,
  deleteStockAdjustment
};
