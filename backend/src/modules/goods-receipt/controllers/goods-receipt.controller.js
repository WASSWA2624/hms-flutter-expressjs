/**
 * Goods receipt controller
 */

const goodsReceiptService = require('@services/goods-receipt/goods-receipt.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendCreated, sendNoContent } = require('@lib/response');

const getGoodsReceipt = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const goodsReceipt = await goodsReceiptService.getGoodsReceiptById(id);
  sendSuccess(res, goodsReceipt, 'messages.goods_receipt.retrieved', req.locale);
});

const listGoodsReceipts = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  const result = await goodsReceiptService.listGoodsReceipts(
    filters,
    { page: parseInt(page) || 1, limit: parseInt(limit) || 20 },
    { sort_by, order }
  );
  sendSuccess(res, result.data, 'messages.goods_receipt.list_retrieved', req.locale, {
    pagination: {
      page: result.page,
      limit: result.limit,
      total: result.total,
      total_pages: Math.ceil(result.total / result.limit)
    }
  });
});

const createGoodsReceipt = asyncHandler(async (req, res) => {
  const goodsReceiptData = req.body;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  const goodsReceipt = await goodsReceiptService.createGoodsReceipt(goodsReceiptData, auditContext);
  sendCreated(res, goodsReceipt, 'messages.goods_receipt.created', req.locale);
});

const updateGoodsReceipt = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateData = req.body;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  const goodsReceipt = await goodsReceiptService.updateGoodsReceipt(id, updateData, auditContext);
  sendSuccess(res, goodsReceipt, 'messages.goods_receipt.updated', req.locale);
});

const deleteGoodsReceipt = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const auditContext = { user_id: req.user?.id, ip_address: req.ip };
  await goodsReceiptService.deleteGoodsReceipt(id, auditContext);
  sendNoContent(res);
});

module.exports = {
  getGoodsReceipt,
  listGoodsReceipts,
  createGoodsReceipt,
  updateGoodsReceipt,
  deleteGoodsReceipt
};
