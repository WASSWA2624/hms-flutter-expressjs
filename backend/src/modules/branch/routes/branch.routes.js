/**
 * Branch routes
 *
 * @module modules/branch/routes
 * @description Branch endpoints mounted at /api/v1/branches
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const branchController = require('@controllers/branch/branch.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createBranchSchema,
  updateBranchSchema,
  branchIdParamsSchema,
  listBranchesQuerySchema
} = require('@validations/branch/branch.schema');

/**
 * @description List branches with pagination and filters
 * @method GET
 * @route /api/v1/branches/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search by name
 * @bodyParams None
 * @returns {Object} Paginated list of branches
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listBranchesQuerySchema }),

  authenticate(),
  branchController.listBranches
);

/**
 * @description Get branch by ID
 * @method GET
 * @route /api/v1/branches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Branch ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Branch data
 * @throws 401 Unauthorized
 * @throws 404 Branch not found
 */
router.get(
  '/:id',  validateRequest({ params: branchIdParamsSchema }),

  authenticate(),
  branchController.getBranchById
);

/**
 * @description Create new branch
 * @method POST
 * @route /api/v1/branches/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} name - Branch name (required, max 255 chars)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created branch
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createBranchSchema }),

  authenticate(),
  branchController.createBranch
);

/**
 * @description Update branch
 * @method PUT
 * @route /api/v1/branches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Branch ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [name] - Branch name (max 255 chars)
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated branch
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Branch not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: branchIdParamsSchema, body: updateBranchSchema }),

  authenticate(),
  branchController.updateBranch
);

/**
 * @description Delete branch (soft delete)
 * @method DELETE
 * @route /api/v1/branches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Branch ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Branch not found
 */
router.delete(
  '/:id',  validateRequest({ params: branchIdParamsSchema }),

  authenticate(),
  branchController.deleteBranch
);

module.exports = router;
