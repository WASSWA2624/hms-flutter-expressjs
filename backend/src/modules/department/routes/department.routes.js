/**
 * Department routes
 *
 * @module modules/department/routes
 * @description Department endpoints mounted at /api/v1/departments
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const departmentController = require('@controllers/department/department.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createDepartmentSchema,
  updateDepartmentSchema,
  departmentIdParamsSchema,
  listDepartmentsQuerySchema
} = require('@validations/department/department.schema');

/**
 * @description List departments with pagination and filters
 * @method GET
 * @route /api/v1/departments/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [branch_id] - Filter by branch ID (UUID)
 * @queryParams {string} [department_type] - Filter by department type
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search by name
 * @bodyParams None
 * @returns {Object} Paginated list of departments
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listDepartmentsQuerySchema }),

  authenticate(),
  departmentController.listDepartments
);

/**
 * @description Get department by ID
 * @method GET
 * @route /api/v1/departments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Department ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Department data
 * @throws 401 Unauthorized
 * @throws 404 Department not found
 */
router.get(
  '/:id',  validateRequest({ params: departmentIdParamsSchema }),

  authenticate(),
  departmentController.getDepartmentById
);

/**
 * @description Create new department
 * @method POST
 * @route /api/v1/departments/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [branch_id] - Branch ID (UUID)
 * @bodyParams {string} name - Department name (required, max 255 chars)
 * @bodyParams {string} department_type - Department type (required)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created department
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createDepartmentSchema }),

  authenticate(),
  departmentController.createDepartment
);

/**
 * @description Update department
 * @method PUT
 * @route /api/v1/departments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Department ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [branch_id] - Branch ID (UUID)
 * @bodyParams {string} [name] - Department name (max 255 chars)
 * @bodyParams {string} [department_type] - Department type
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated department
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Department not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: departmentIdParamsSchema, body: updateDepartmentSchema }),

  authenticate(),
  departmentController.updateDepartment
);

/**
 * @description Delete department (soft delete)
 * @method DELETE
 * @route /api/v1/departments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Department ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Department not found
 */
router.delete(
  '/:id',  validateRequest({ params: departmentIdParamsSchema }),

  authenticate(),
  departmentController.deleteDepartment
);

/**
 * @description Get department units (nested resource)
 * @method GET
 * @route /api/v1/departments/:id/units
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Department ID (UUID)
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @bodyParams None
 * @returns {Object} Paginated list of units
 * @throws 401 Unauthorized
 * @throws 404 Department not found
 */
router.get(
  '/:id/units',  validateRequest({ params: departmentIdParamsSchema }),

  authenticate(),
  departmentController.getDepartmentUnits
);

module.exports = router;
