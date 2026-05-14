/**
 * Tenant controller
 *
 * @module modules/tenant/controllers
 * @description Handles HTTP requests for tenant endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const tenantService = require('@services/tenant/tenant.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List tenants with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listTenants = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, is_active, search } = req.query;

  const filters = {};
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;

  const result = await tenantService.listTenants(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.tenant.list.success',
    result.tenants,
    result.pagination
  );
});

/**
 * Get tenant by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getTenantById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const tenant = await tenantService.getTenantById(id);

  return sendSuccess(res, 200, 'messages.tenant.get.success', tenant);
});

/**
 * Create tenant
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createTenant = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const tenant = await tenantService.createTenant(data, context);

  return sendSuccess(res, 201, 'messages.tenant.create.success', tenant);
});

/**
 * Update tenant
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateTenant = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const tenant = await tenantService.updateTenant(id, data, context);

  return sendSuccess(res, 200, 'messages.tenant.update.success', tenant);
});

/**
 * Delete tenant
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteTenant = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await tenantService.deleteTenant(id, context);

  return sendNoContent(res);
});

module.exports = {
  listTenants,
  getTenantById,
  createTenant,
  updateTenant,
  deleteTenant
};
