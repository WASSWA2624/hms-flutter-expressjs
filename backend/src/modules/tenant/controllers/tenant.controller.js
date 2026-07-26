/**
 * Tenant controller
 *
 * @module modules/tenant/controllers
 * @description Handles HTTP requests for tenant endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const { PERMISSIONS } = require('@config/permissions');
const tenantService = require('@services/tenant/tenant.service');
const { asyncHandler } = require('@lib/async');
const { HttpError } = require('@lib/errors');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

const buildRequestContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  permissions: Array.isArray(req.user?.permissions) ? req.user.permissions : [],
  ip_address: req.ip,
  user_agent: req.get('user-agent')
});

const isSystemAdmin = (context) =>
  Array.isArray(context.permissions)
  && context.permissions.includes(PERMISSIONS.SYSTEM_ADMIN);

/**
 * List tenants with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listTenants = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, is_active, search, include_deleted } = req.query;
  const context = buildRequestContext(req);

  const filters = {};
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;
  if (include_deleted === 'true') {
    if (!isSystemAdmin(context)) {
      throw new HttpError('errors.auth.insufficient_permissions', 403);
    }
    filters.include_deleted = true;
  }
  if (!isSystemAdmin(context)) {
    if (!context.tenant_id) {
      throw new HttpError('errors.auth.insufficient_permissions', 403);
    }
    filters.id = context.tenant_id;
  }

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
  const context = buildRequestContext(req);

  const tenant = await tenantService.getTenantById(id, context);

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
  const context = buildRequestContext(req);

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
  const context = buildRequestContext(req);

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
  const context = buildRequestContext(req);

  await tenantService.deleteTenant(id, context);

  return sendNoContent(res);
});

const restoreTenant = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const context = buildRequestContext(req);

  const tenant = await tenantService.restoreTenant(id, context);

  return sendSuccess(res, 200, 'messages.tenant.restore.success', tenant);
});

const permanentDeleteTenant = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const context = buildRequestContext(req);

  await tenantService.permanentDeleteTenant(id, context);

  return sendNoContent(res);
});

module.exports = {
  listTenants,
  getTenantById,
  createTenant,
  updateTenant,
  deleteTenant,
  restoreTenant,
  permanentDeleteTenant};
