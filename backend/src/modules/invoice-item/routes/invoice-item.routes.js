/**
 * Invoice item routes
 *
 * @module modules/invoice-item/routes
 * @description Invoice item endpoints mounted at /api/v1/invoice-items
 */

const express = require('express');
const router = express.Router();
const invoiceItemController = require('@controllers/invoice-item/invoice-item.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createInvoiceItemSchema,
  updateInvoiceItemSchema,
  invoiceItemIdParamsSchema,
  listInvoiceItemsQuerySchema
} = require('@validations/invoice-item/invoice-item.schema');

/**
 * @description List invoice items with pagination and filters
 * @method GET
 * @route /api/v1/invoice-items/
 * @authentication Required (JWT)
 */
router.get(
  '/',  validateRequest({ query: listInvoiceItemsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  invoiceItemController.listInvoiceItems
);

/**
 * @description Get invoice item by ID
 * @method GET
 * @route /api/v1/invoice-items/:id
 * @authentication Required (JWT)
 */
router.get(
  '/:id',  validateRequest({ params: invoiceItemIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  invoiceItemController.getInvoiceItemById
);

/**
 * @description Create invoice item
 * @method POST
 * @route /api/v1/invoice-items/
 * @authentication Required (JWT)
 */
router.post(
  '/',  validateRequest({ body: createInvoiceItemSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  invoiceItemController.createInvoiceItem
);

/**
 * @description Update invoice item
 * @method PUT
 * @route /api/v1/invoice-items/:id
 * @authentication Required (JWT)
 */
router.put(
  '/:id',  validateRequest({ params: invoiceItemIdParamsSchema, body: updateInvoiceItemSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  invoiceItemController.updateInvoiceItem
);

/**
 * @description Delete invoice item (soft delete)
 * @method DELETE
 * @route /api/v1/invoice-items/:id
 * @authentication Required (JWT)
 */
router.delete(
  '/:id',  validateRequest({ params: invoiceItemIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  invoiceItemController.deleteInvoiceItem
);

module.exports = router;
