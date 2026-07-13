/**
 * Price Book Entry routes
 *
 * @module modules/price-book-entry/routes
 * @description Price Book Entry endpoints mounted at /api/v1/price-book-entries
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const priceBookEntryController = require('@controllers/price-book-entry/price-book-entry.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPriceBookEntrySchema,
  updatePriceBookEntrySchema,
  resolvePriceBookEntriesSchema,
  priceBookEntryIdParamsSchema,
  listPriceBookEntriesQuerySchema
} = require('@validations/price-book-entry/price-book-entry.schema');

/**
 * @description List price book entries with pagination and filters
 * @method GET
 * @route /api/v1/price-book-entries/
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/',
  validateRequest({ query: listPriceBookEntriesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  priceBookEntryController.listPriceBookEntries
);

/**
 * @description Resolve unit prices for catalog line items
 * @method POST
 * @route /api/v1/price-book-entries/resolve
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.post(
  '/resolve',
  validateRequest({ body: resolvePriceBookEntriesSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  priceBookEntryController.resolvePriceBookEntries
);

/**
 * @description Get price book entry by ID
 * @method GET
 * @route /api/v1/price-book-entries/:id
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/:id',
  validateRequest({ params: priceBookEntryIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  priceBookEntryController.getPriceBookEntryById
);

/**
 * @description Create new price book entry
 * @method POST
 * @route /api/v1/price-book-entries/
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.post(
  '/',
  validateRequest({ body: createPriceBookEntrySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  priceBookEntryController.createPriceBookEntry
);

/**
 * @description Update price book entry
 * @method PUT
 * @route /api/v1/price-book-entries/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.put(
  '/:id',
  validateRequest({ params: priceBookEntryIdParamsSchema, body: updatePriceBookEntrySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  priceBookEntryController.updatePriceBookEntry
);

/**
 * @description Delete price book entry (soft delete)
 * @method DELETE
 * @route /api/v1/price-book-entries/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.delete(
  '/:id',
  validateRequest({ params: priceBookEntryIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  priceBookEntryController.deletePriceBookEntry
);

module.exports = router;
