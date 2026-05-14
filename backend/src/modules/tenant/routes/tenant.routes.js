/**
 * Tenant routes
 *
 * @module modules/tenant/routes
 * @description Tenant endpoints mounted at /api/v1/tenants
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const tenantController = require('@controllers/tenant/tenant.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createTenantSchema,
  updateTenantSchema,
  tenantIdParamsSchema,
  listTenantsQuerySchema
} = require('@validations/tenant/tenant.schema');

/**
 * @description List tenants with pagination and filters
 * @method GET
 * @route /api/v1/tenants/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search by name or slug
 * @bodyParams None
 * @returns {Object} Paginated list of tenants
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listTenantsQuerySchema }),

  authenticate(),
  tenantController.listTenants
);

/**
 * @description Get tenant by ID
 * @method GET
 * @route /api/v1/tenants/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Tenant ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Tenant data
 * @throws 401 Unauthorized
 * @throws 404 Tenant not found
 */
router.get(
  '/:id',  validateRequest({ params: tenantIdParamsSchema }),

  authenticate(),
  tenantController.getTenantById
);

/**
 * @description Create new tenant
 * @method POST
 * @route /api/v1/tenants/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} name - Tenant name (required, max 255 chars)
 * @bodyParams {string} [slug] - Tenant slug (max 191 chars)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created tenant
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 409 Duplicate slug
 */
router.post(
  '/',  validateRequest({ body: createTenantSchema }),

  authenticate(),
  tenantController.createTenant
);

/**
 * @description Update tenant
 * @method PUT
 * @route /api/v1/tenants/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Tenant ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Tenant name (max 255 chars)
 * @bodyParams {string} [slug] - Tenant slug (max 191 chars)
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated tenant
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Tenant not found
 * @throws 409 Duplicate slug
 */
router.put(
  '/:id',  validateRequest({ params: tenantIdParamsSchema, body: updateTenantSchema }),

  authenticate(),
  tenantController.updateTenant
);

/**
 * @description Delete tenant (soft delete)
 * @method DELETE
 * @route /api/v1/tenants/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Tenant ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Tenant not found
 */
router.delete(
  '/:id',  validateRequest({ params: tenantIdParamsSchema }),

  authenticate(),
  tenantController.deleteTenant
);

module.exports = router;
