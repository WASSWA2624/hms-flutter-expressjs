/**
 * Drug routes
 *
 * @module modules/drug/routes
 * @description Drug endpoints mounted at /api/v1/drugs
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const drugController = require('@controllers/drug/drug.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createDrugSchema,
  updateDrugSchema,
  drugIdParamsSchema,
  listDrugsQuerySchema
} = require('@validations/drug/drug.schema');

/**
 * @description List drugs with pagination and filters
 * @method GET
 * @route /api/v1/drugs/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [name] - Filter by drug name (partial match)
 * @queryParams {string} [code] - Filter by drug code (partial match)
 * @queryParams {string} [form] - Filter by drug form (partial match)
 * @queryParams {string} [strength] - Filter by drug strength (partial match)
 * @queryParams {string} [search] - Search in name and code fields
 * @bodyParams None
 * @returns {Object} Paginated list of drugs
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listDrugsQuerySchema }),

  authenticate(),
  drugController.listDrugs
);

/**
 * @description Get drug by ID
 * @method GET
 * @route /api/v1/drugs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Drug ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Drug data
 * @throws 401 Unauthorized
 * @throws 404 Drug not found
 */
router.get(
  '/:id',  validateRequest({ params: drugIdParamsSchema }),

  authenticate(),
  drugController.getDrugById
);

/**
 * @description Create new drug
 * @method POST
 * @route /api/v1/drugs/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Drug name (required, max 255 chars)
 * @bodyParams {string} [code] - Drug code (max 80 chars)
 * @bodyParams {string} [form] - Drug form (max 80 chars)
 * @bodyParams {string} [strength] - Drug strength (max 80 chars)
 * @returns {Object} Created drug
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createDrugSchema }),

  authenticate(),
  drugController.createDrug
);

/**
 * @description Update drug
 * @method PUT
 * @route /api/v1/drugs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Drug ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Drug name (max 255 chars)
 * @bodyParams {string} [code] - Drug code (max 80 chars)
 * @bodyParams {string} [form] - Drug form (max 80 chars)
 * @bodyParams {string} [strength] - Drug strength (max 80 chars)
 * @returns {Object} Updated drug
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Drug not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: drugIdParamsSchema, body: updateDrugSchema }),

  authenticate(),
  drugController.updateDrug
);

/**
 * @description Delete drug (soft delete)
 * @method DELETE
 * @route /api/v1/drugs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Drug ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Drug not found
 */
router.delete(
  '/:id',  validateRequest({ params: drugIdParamsSchema }),

  authenticate(),
  drugController.deleteDrug
);

module.exports = router;
