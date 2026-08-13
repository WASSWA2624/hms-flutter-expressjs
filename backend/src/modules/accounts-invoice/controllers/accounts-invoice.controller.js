/**
 * Accounts Invoice controller.
 */

const accountsInvoiceService = require('@services/accounts-invoice/accounts-invoice.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listAccountsInvoices = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    status,
    search,
    date_from,
    date_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
  } = req.query;

  const result = await accountsInvoiceService.listAccountsInvoices(
    { tenant_id, facility_id, status, search, date_from, date_to },
    parseInt(page, 10),
    parseInt(limit, 10)
  );

  sendPaginated(
    res,
    'messages.accounts_invoice.list.success',
    result.accountsInvoices,
    result.pagination
  );
});

const getAccountsInvoiceById = asyncHandler(async (req, res) => {
  const invoice = await accountsInvoiceService.getAccountsInvoiceById(req.params.id);
  sendSuccess(res, 200, 'messages.accounts_invoice.get.success', invoice);
});

const createAccountsInvoice = asyncHandler(async (req, res) => {
  const invoice = await accountsInvoiceService.createAccountsInvoice(
    req.body,
    req.user?.id,
    req.ip
  );
  sendSuccess(res, 201, 'messages.accounts_invoice.create.success', invoice);
});

const updateAccountsInvoice = asyncHandler(async (req, res) => {
  const invoice = await accountsInvoiceService.updateAccountsInvoice(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  sendSuccess(res, 200, 'messages.accounts_invoice.update.success', invoice);
});

const voidAccountsInvoice = asyncHandler(async (req, res) => {
  const invoice = await accountsInvoiceService.voidAccountsInvoice(
    req.params.id,
    req.body,
    req.user?.id,
    req.ip
  );
  sendSuccess(res, 200, 'messages.accounts_invoice.void.success', invoice);
});

module.exports = {
  listAccountsInvoices,
  getAccountsInvoiceById,
  createAccountsInvoice,
  updateAccountsInvoice,
  voidAccountsInvoice,
};
