/**
 * Invoice controller
 *
 * @module modules/invoice/controllers
 * @description Request handlers for invoice endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const invoiceService = require('@services/invoice/invoice.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List invoices with pagination
 * GET /api/v1/invoices
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listInvoices = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    status,
    billing_status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    status,
    billing_status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await invoiceService.listInvoices(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.invoice.list.success', result.invoices, result.pagination);
});

/**
 * Get invoice by ID
 * GET /api/v1/invoices/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getInvoiceById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const invoice = await invoiceService.getInvoiceById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.invoice.get.success', invoice);
});

/**
 * Create new invoice
 * POST /api/v1/invoices
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createInvoice = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const invoice = await invoiceService.createInvoice(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.invoice.create.success', invoice);
});

/**
 * Update invoice
 * PUT /api/v1/invoices/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateInvoice = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const invoice = await invoiceService.updateInvoice(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.invoice.update.success', invoice);
});

/**
 * Delete invoice (soft delete)
 * DELETE /api/v1/invoices/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteInvoice = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await invoiceService.deleteInvoice(id, userId, ipAddress);

  sendNoContent(res, 'messages.invoice.delete.success');
});

module.exports = {
  listInvoices,
  getInvoiceById,
  createInvoice,
  updateInvoice,
  deleteInvoice
};
