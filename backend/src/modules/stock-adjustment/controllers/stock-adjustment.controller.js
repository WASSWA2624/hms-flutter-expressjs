/**
 * Stock adjustment controller
 */

const stockAdjustmentService = require('@services/stock-adjustment/stock-adjustment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendCreated, sendNoContent } = require('@lib/response');

const getStockAdjustment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const stockAdjustment = await stockAdjustmentService.getStockAdjustmentById(id);
  sendSuccess(res, stockAdjustment, 'messages.stock_adjustment.retrieved', req.locale);
});

const listStockAdjustments = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  const result = await stockAdjustmentService.listStockAdjustments(
    filters,
    { page: parseInt(page) || 1, limit: parseInt(limit) || 20 },
    { sort_by, order }
  );
  sendSuccess(res, result.data, 'messages.stock_adjustment.list_retrieved', req.locale, {
    pagination: {
      page: result.page,
      limit: result.limit,
      total: result.total,
      total_pages: Math.ceil(result.total / result.limit)
    }
  });
});

const createStockAdjustment = asyncHandler(async (req, res) => {
  const stockAdjustmentData = req.body;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  const stockAdjustment = await stockAdjustmentService.createStockAdjustment(stockAdjustmentData, auditContext);
  sendCreated(res, stockAdjustment, 'messages.stock_adjustment.created', req.locale);
});

const updateStockAdjustment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateData = req.body;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  const stockAdjustment = await stockAdjustmentService.updateStockAdjustment(id, updateData, auditContext);
  sendSuccess(res, stockAdjustment, 'messages.stock_adjustment.updated', req.locale);
});

const deleteStockAdjustment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  await stockAdjustmentService.deleteStockAdjustment(id, auditContext);
  sendNoContent(res);
});

module.exports = {
  getStockAdjustment,
  listStockAdjustments,
  createStockAdjustment,
  updateStockAdjustment,
  deleteStockAdjustment
};
