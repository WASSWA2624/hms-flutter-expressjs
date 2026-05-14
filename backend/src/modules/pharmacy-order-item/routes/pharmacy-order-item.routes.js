/**
 * Pharmacy order item routes
 *
 * @module modules/pharmacy-order-item/routes
 * @description Pharmacy order item endpoints mounted at /api/v1/pharmacy-order-items
 */

const express = require('express');
const router = express.Router();
const pharmacyOrderItemController = require('@controllers/pharmacy-order-item/pharmacy-order-item.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createPharmacyOrderItemSchema,
  updatePharmacyOrderItemSchema,
  pharmacyOrderItemIdParamsSchema,
  listPharmacyOrderItemsQuerySchema
} = require('@validations/pharmacy-order-item/pharmacy-order-item.schema');

/**
 * @description List pharmacy order items with pagination and filters
 * @method GET
 * @route /api/v1/pharmacy-order-items/
 * @authentication Required (JWT)
 */
router.get(
  '/',  validateRequest({ query: listPharmacyOrderItemsQuerySchema }),

  authenticate(),
  pharmacyOrderItemController.listPharmacyOrderItems
);

/**
 * @description Get pharmacy order item by ID
 * @method GET
 * @route /api/v1/pharmacy-order-items/:id
 * @authentication Required (JWT)
 */
router.get(
  '/:id',  validateRequest({ params: pharmacyOrderItemIdParamsSchema }),

  authenticate(),
  pharmacyOrderItemController.getPharmacyOrderItemById
);

/**
 * @description Create pharmacy order item
 * @method POST
 * @route /api/v1/pharmacy-order-items/
 * @authentication Required (JWT)
 */
router.post(
  '/',  validateRequest({ body: createPharmacyOrderItemSchema }),

  authenticate(),
  pharmacyOrderItemController.createPharmacyOrderItem
);

/**
 * @description Update pharmacy order item
 * @method PUT
 * @route /api/v1/pharmacy-order-items/:id
 * @authentication Required (JWT)
 */
router.put(
  '/:id',  validateRequest({ params: pharmacyOrderItemIdParamsSchema, body: updatePharmacyOrderItemSchema }),

  authenticate(),
  pharmacyOrderItemController.updatePharmacyOrderItem
);

/**
 * @description Delete pharmacy order item (soft delete)
 * @method DELETE
 * @route /api/v1/pharmacy-order-items/:id
 * @authentication Required (JWT)
 */
router.delete(
  '/:id',  validateRequest({ params: pharmacyOrderItemIdParamsSchema }),

  authenticate(),
  pharmacyOrderItemController.deletePharmacyOrderItem
);

module.exports = router;

