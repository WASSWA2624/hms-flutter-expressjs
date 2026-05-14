/**
 * Invoice routes
 *
 * @module modules/invoice/routes
 * @description Invoice endpoints mounted at /api/v1/invoices
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const invoiceController = require('@controllers/invoice/invoice.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createInvoiceSchema,
  updateInvoiceSchema,
  invoiceIdParamsSchema,
  listInvoicesQuerySchema
} = require('@validations/invoice/invoice.schema');

/**
 * @description List invoices with pagination and filters
 * @method GET
 * @route /api/v1/invoices/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [status] - Filter by status (DRAFT, SENT, PAID, OVERDUE, CANCELLED)
 * @queryParams {string} [billing_status] - Filter by billing status (DRAFT, ISSUED, PAID, PARTIAL, CANCELLED)
 * @queryParams {string} [search] - Search in invoice ID
 * @bodyParams None
 * @returns {Object} Paginated list of invoices
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listInvoicesQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  invoiceController.listInvoices
);

/**
 * @description Get invoice by ID
 * @method GET
 * @route /api/v1/invoices/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Invoice ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Invoice data
 * @throws 401 Unauthorized
 * @throws 404 Invoice not found
 */
router.get(
  '/:id',  validateRequest({ params: invoiceIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  invoiceController.getInvoiceById
);

/**
 * @description Create new invoice
 * @method POST
 * @route /api/v1/invoices/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} status - Invoice status (required, DRAFT/SENT/PAID/OVERDUE/CANCELLED)
 * @bodyParams {string} [billing_status=DRAFT] - Billing status (DRAFT/ISSUED/PAID/PARTIAL/CANCELLED)
 * @bodyParams {string} total_amount - Total amount (required, decimal string)
 * @bodyParams {string} currency - Currency code (required, max 10 chars)
 * @bodyParams {string} [issued_at] - Issue date (ISO datetime)
 * @returns {Object} Created invoice
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createInvoiceSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  invoiceController.createInvoice
);

/**
 * @description Update invoice
 * @method PUT
 * @route /api/v1/invoices/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Invoice ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [status] - Invoice status (DRAFT/SENT/PAID/OVERDUE/CANCELLED)
 * @bodyParams {string} [billing_status] - Billing status (DRAFT/ISSUED/PAID/PARTIAL/CANCELLED)
 * @bodyParams {string} [total_amount] - Total amount (decimal string)
 * @bodyParams {string} [currency] - Currency code (max 10 chars)
 * @bodyParams {string} [issued_at] - Issue date (ISO datetime)
 * @returns {Object} Updated invoice
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Invoice not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: invoiceIdParamsSchema, body: updateInvoiceSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  invoiceController.updateInvoice
);

/**
 * @description Delete invoice (soft delete)
 * @method DELETE
 * @route /api/v1/invoices/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Invoice ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Invoice not found
 */
router.delete(
  '/:id',  validateRequest({ params: invoiceIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  invoiceController.deleteInvoice
);

module.exports = router;
