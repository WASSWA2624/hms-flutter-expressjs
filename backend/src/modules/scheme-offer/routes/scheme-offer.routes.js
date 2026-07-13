/**
 * Scheme Offer routes
 *
 * @module modules/scheme-offer/routes
 * @description Scheme Offer endpoints mounted at /api/v1/scheme-offers
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const schemeOfferController = require('@controllers/scheme-offer/scheme-offer.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createSchemeOfferSchema,
  updateSchemeOfferSchema,
  schemeOfferIdParamsSchema,
  listSchemeOffersQuerySchema
} = require('@validations/scheme-offer/scheme-offer.schema');

/**
 * @description List scheme offers with pagination and filters
 * @method GET
 * @route /api/v1/scheme-offers/
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/',
  validateRequest({ query: listSchemeOffersQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  schemeOfferController.listSchemeOffers
);

/**
 * @description Get scheme offer by ID
 * @method GET
 * @route /api/v1/scheme-offers/:id
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/:id',
  validateRequest({ params: schemeOfferIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  schemeOfferController.getSchemeOfferById
);

/**
 * @description Create new scheme offer
 * @method POST
 * @route /api/v1/scheme-offers/
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.post(
  '/',
  validateRequest({ body: createSchemeOfferSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  schemeOfferController.createSchemeOffer
);

/**
 * @description Update scheme offer
 * @method PUT
 * @route /api/v1/scheme-offers/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.put(
  '/:id',
  validateRequest({ params: schemeOfferIdParamsSchema, body: updateSchemeOfferSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  schemeOfferController.updateSchemeOffer
);

/**
 * @description Delete scheme offer (soft delete)
 * @method DELETE
 * @route /api/v1/scheme-offers/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.delete(
  '/:id',
  validateRequest({ params: schemeOfferIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  schemeOfferController.deleteSchemeOffer
);

module.exports = router;
