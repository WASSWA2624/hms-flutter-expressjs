/**
 * Formulary item routes
 *
 * @module modules/formulary-item/routes
 * @description Formulary item endpoints mounted at /api/v1/formulary-items
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const formularyItemController = require('@controllers/formulary-item/formulary-item.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createFormularyItemSchema,
  updateFormularyItemSchema,
  formularyItemIdParamsSchema,
  listFormularyItemsQuerySchema
} = require('@validations/formulary-item/formulary-item.schema');

/**
 * @description List formulary items with pagination and filters
 * @method GET
 * @route /api/v1/formulary-items/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [drug_id] - Filter by drug ID (UUID)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of formulary items
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listFormularyItemsQuerySchema }),

  authenticate(),
  formularyItemController.listFormularyItems
);

/**
 * @description Get formulary item by ID
 * @method GET
 * @route /api/v1/formulary-items/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Formulary item ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Formulary item data
 * @throws 401 Unauthorized
 * @throws 404 Formulary item not found
 */
router.get(
  '/:id',  validateRequest({ params: formularyItemIdParamsSchema }),

  authenticate(),
  formularyItemController.getFormularyItemById
);

/**
 * @description Create new formulary item
 * @method POST
 * @route /api/v1/formulary-items/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} drug_id - Drug ID (required, UUID)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created formulary item
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createFormularyItemSchema }),

  authenticate(),
  formularyItemController.createFormularyItem
);

/**
 * @description Update formulary item
 * @method PUT
 * @route /api/v1/formulary-items/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Formulary item ID (UUID)
 * @queryParams None
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated formulary item
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Formulary item not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: formularyItemIdParamsSchema, body: updateFormularyItemSchema }),

  authenticate(),
  formularyItemController.updateFormularyItem
);

/**
 * @description Delete formulary item (soft delete)
 * @method DELETE
 * @route /api/v1/formulary-items/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Formulary item ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Formulary item not found
 */
router.delete(
  '/:id',  validateRequest({ params: formularyItemIdParamsSchema }),

  authenticate(),
  formularyItemController.deleteFormularyItem
);

module.exports = router;
