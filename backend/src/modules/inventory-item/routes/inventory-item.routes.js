/**
 * Inventory item routes
 *
 * @module modules/inventory-item/routes
 * @description Inventory item endpoints mounted at /api/v1/inventory-items
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const inventoryItemController = require('@controllers/inventory-item/inventory-item.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createInventoryItemSchema,
  updateInventoryItemSchema,
  inventoryItemIdParamsSchema,
  listInventoryItemsQuerySchema
} = require('@validations/inventory-item/inventory-item.schema');

/**
 * @description List inventory items with pagination and filters
 * @method GET
 * @route /api/v1/inventory-items/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [name] - Filter by item name (partial match)
 * @queryParams {string} [category] - Filter by category (MEDICATION, SUPPLY, EQUIPMENT, OTHER)
 * @queryParams {string} [sku] - Filter by SKU (partial match)
 * @queryParams {string} [unit] - Filter by unit (partial match)
 * @queryParams {string} [search] - Search in name and SKU fields
 * @bodyParams None
 * @returns {Object} Paginated list of inventory items
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listInventoryItemsQuerySchema }),

  authenticate(),
  inventoryItemController.listInventoryItems
);

/**
 * @description Get inventory item by ID
 * @method GET
 * @route /api/v1/inventory-items/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Inventory item ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Inventory item data
 * @throws 401 Unauthorized
 * @throws 404 Inventory item not found
 */
router.get(
  '/:id',  validateRequest({ params: inventoryItemIdParamsSchema }),

  authenticate(),
  inventoryItemController.getInventoryItemById
);

/**
 * @description Create new inventory item
 * @method POST
 * @route /api/v1/inventory-items/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Item name (required, max 255 chars)
 * @bodyParams {string} category - Category (required, MEDICATION, SUPPLY, EQUIPMENT, OTHER)
 * @bodyParams {string} [sku] - Stock keeping unit (max 80 chars)
 * @bodyParams {string} [unit] - Unit of measurement (max 40 chars)
 * @returns {Object} Created inventory item
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createInventoryItemSchema }),

  authenticate(),
  inventoryItemController.createInventoryItem
);

/**
 * @description Update inventory item
 * @method PUT
 * @route /api/v1/inventory-items/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Inventory item ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Item name (max 255 chars)
 * @bodyParams {string} [category] - Category (MEDICATION, SUPPLY, EQUIPMENT, OTHER)
 * @bodyParams {string} [sku] - Stock keeping unit (max 80 chars)
 * @bodyParams {string} [unit] - Unit of measurement (max 40 chars)
 * @returns {Object} Updated inventory item
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Inventory item not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: inventoryItemIdParamsSchema, body: updateInventoryItemSchema }),

  authenticate(),
  inventoryItemController.updateInventoryItem
);

/**
 * @description Delete inventory item (soft delete)
 * @method DELETE
 * @route /api/v1/inventory-items/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Inventory item ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Inventory item not found
 */
router.delete(
  '/:id',  validateRequest({ params: inventoryItemIdParamsSchema }),

  authenticate(),
  inventoryItemController.deleteInventoryItem
);

module.exports = router;
