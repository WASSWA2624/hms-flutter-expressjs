/**
 * Accounts Invoice routes — mounted at /api/v1/accounts-invoices
 */

const express = require('express');
const router = express.Router();
const accountsInvoiceController = require('@controllers/accounts-invoice/accounts-invoice.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createAccountsInvoiceSchema,
  updateAccountsInvoiceSchema,
  voidAccountsInvoiceSchema,
  accountsInvoiceIdParamsSchema,
  listAccountsInvoicesQuerySchema,
} = require('@validations/accounts-invoice/accounts-invoice.schema');

const ACCOUNTS_READ_SCOPES = [
  PERMISSIONS.ACCOUNTS_READ,
  PERMISSIONS.ACCOUNTS_WRITE,
];

const ACCOUNTS_WRITE_SCOPES = [
  PERMISSIONS.ACCOUNTS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
];

router.get(
  '/',
  validateRequest({ query: listAccountsInvoicesQuerySchema }),
  authenticate(),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsInvoiceController.listAccountsInvoices
);

router.get(
  '/:id',
  validateRequest({ params: accountsInvoiceIdParamsSchema }),
  authenticate(),
  authorize(ACCOUNTS_READ_SCOPES, 'permission'),
  accountsInvoiceController.getAccountsInvoiceById
);

router.post(
  '/',
  validateRequest({ body: createAccountsInvoiceSchema }),
  authenticate(),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  accountsInvoiceController.createAccountsInvoice
);

router.put(
  '/:id',
  validateRequest({
    params: accountsInvoiceIdParamsSchema,
    body: updateAccountsInvoiceSchema,
  }),
  authenticate(),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  accountsInvoiceController.updateAccountsInvoice
);

router.post(
  '/:id/void',
  validateRequest({
    params: accountsInvoiceIdParamsSchema,
    body: voidAccountsInvoiceSchema,
  }),
  authenticate(),
  authorize(ACCOUNTS_WRITE_SCOPES, 'permission'),
  accountsInvoiceController.voidAccountsInvoice
);

module.exports = router;
