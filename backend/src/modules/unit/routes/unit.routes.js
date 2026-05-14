/**
 * Unit routes
 *
 * @module modules/unit/routes
 * @description Unit endpoints mounted at /api/v1/units
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const unitController = require('@controllers/unit/unit.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createUnitSchema,
  updateUnitSchema,
  unitIdParamsSchema,
  listUnitsQuerySchema
} = require('@validations/unit/unit.schema');

/**
 * @description List units with pagination and filters
 * @method GET
 * @route /api/v1/units/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [department_id] - Filter by department ID (UUID)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search by name
 * @bodyParams None
 * @returns {Object} Paginated list of units
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listUnitsQuerySchema }),

  authenticate(),
  unitController.listUnits
);

/**
 * @description Get unit by ID
 * @method GET
 * @route /api/v1/units/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Unit ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Unit data
 * @throws 401 Unauthorized
 * @throws 404 Unit not found
 */
router.get(
  '/:id',  validateRequest({ params: unitIdParamsSchema }),

  authenticate(),
  unitController.getUnitById
);

/**
 * @description Create new unit
 * @method POST
 * @route /api/v1/units/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [department_id] - Department ID (UUID)
 * @bodyParams {string} name - Unit name (required, max 255 chars)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created unit
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createUnitSchema }),

  authenticate(),
  unitController.createUnit
);

/**
 * @description Update unit
 * @method PUT
 * @route /api/v1/units/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Unit ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [department_id] - Department ID (UUID)
 * @bodyParams {string} [name] - Unit name (max 255 chars)
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated unit
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Unit not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: unitIdParamsSchema, body: updateUnitSchema }),

  authenticate(),
  unitController.updateUnit
);

/**
 * @description Delete unit (soft delete)
 * @method DELETE
 * @route /api/v1/units/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Unit ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Unit not found
 */
router.delete(
  '/:id',  validateRequest({ params: unitIdParamsSchema }),

  authenticate(),
  unitController.deleteUnit
);

module.exports = router;
