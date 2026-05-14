/**
 * Invoice item controller
 *
 * @module modules/invoice-item/controllers
 * @description Request handlers for invoice item endpoints.
 */

const invoiceItemService = require('@services/invoice-item/invoice-item.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List invoice items with pagination
 * GET /api/v1/invoice-items
 */
const listInvoiceItems = asyncHandler(async (req, res) => {
  const {
    invoice_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    invoice_id,
    search
  };

  const result = await invoiceItemService.listInvoiceItems(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  sendPaginated(res, 'messages.invoice_item.list.success', result.invoiceItems, result.pagination);
});

/**
 * Get invoice item by ID
 * GET /api/v1/invoice-items/:id
 */
const getInvoiceItemById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const invoiceItem = await invoiceItemService.getInvoiceItemById(id);
  sendSuccess(res, 200, 'messages.invoice_item.get.success', invoiceItem);
});

/**
 * Create invoice item
 * POST /api/v1/invoice-items
 */
const createInvoiceItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const invoiceItem = await invoiceItemService.createInvoiceItem(req.body, userId, ipAddress);
  sendSuccess(res, 201, 'messages.invoice_item.create.success', invoiceItem);
});

/**
 * Update invoice item
 * PUT /api/v1/invoice-items/:id
 */
const updateInvoiceItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const invoiceItem = await invoiceItemService.updateInvoiceItem(id, req.body, userId, ipAddress);
  sendSuccess(res, 200, 'messages.invoice_item.update.success', invoiceItem);
});

/**
 * Delete invoice item
 * DELETE /api/v1/invoice-items/:id
 */
const deleteInvoiceItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await invoiceItemService.deleteInvoiceItem(id, userId, ipAddress);
  sendNoContent(res);
});

module.exports = {
  listInvoiceItems,
  getInvoiceItemById,
  createInvoiceItem,
  updateInvoiceItem,
  deleteInvoiceItem
};

