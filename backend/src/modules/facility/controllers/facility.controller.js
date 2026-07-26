/**
 * Facility controller
 *
 * @module modules/facility/controllers
 * @description Handles HTTP requests for facility endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const facilityService = require('@services/facility/facility.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { PERMISSIONS } = require('@config/permissions');

const buildRequestContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  permissions: Array.isArray(req.user?.permissions) ? req.user.permissions : []
});

const hasPermission = (context, permission) =>
  Array.isArray(context.permissions) && context.permissions.includes(permission);

const isSystemAdmin = (context) => hasPermission(context, PERMISSIONS.SYSTEM_ADMIN);

const isTenantAdmin = (context) => hasPermission(context, PERMISSIONS.TENANT_ADMIN);

/**
 * List facilities with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listFacilities = asyncHandler(async (req, res) => {
  const {
    page,
    limit,
    sort_by,
    order,
    tenant_id,
    facility_type,
    is_active,
    search,
    phone,
    email,
    city,
    country,
    include_deleted
  } = req.query;
  const context = buildRequestContext(req);

  const filters = {};
  if (facility_type) filters.facility_type = facility_type;
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;
  if (phone) filters.phone = phone;
  if (email) filters.email = email;
  if (city) filters.city = city;
  if (country) filters.country = country;
  if (include_deleted) filters.include_deleted = include_deleted;

  if (isSystemAdmin(context)) {
    if (tenant_id) filters.tenant_id = tenant_id;
  } else if (
    context.facility_id &&
    !isTenantAdmin(context) &&
    hasPermission(context, PERMISSIONS.FACILITY_ADMIN)
  ) {
    // Facility-admin-only actors see only their facility.
    filters.id = context.facility_id;
    if (context.tenant_id) {
      filters.tenant_id = context.tenant_id;
    }
  } else if (context.tenant_id) {
    filters.tenant_id = context.tenant_id;
  } else {
    throw new HttpError('errors.auth.forbidden', 403);
  }

  const result = await facilityService.listFacilities(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.facility.list.success',
    result.facilities,
    result.pagination
  );
});

/**
 * Get facility by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getFacilityById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const facility = await facilityService.getFacilityById(id);

  return sendSuccess(res, 200, 'messages.facility.get.success', facility);
});

/**
 * Create facility
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createFacility = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const facility = await facilityService.createFacility(data, context);

  return sendSuccess(res, 201, 'messages.facility.create.success', facility);
});

/**
 * Update facility
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateFacility = asyncHandler(async (req, res) => {
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

  const facility = await facilityService.updateFacility(id, data, context);

  return sendSuccess(res, 200, 'messages.facility.update.success', facility);
});

/**
 * Delete facility
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteFacility = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await facilityService.deleteFacility(id, context);

  return sendNoContent(res);
});

const restoreFacility = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const facility = await facilityService.restoreFacility(id, context);

  return sendSuccess(res, 200, 'messages.facility.restore.success', facility);
});

const permanentDeleteFacility = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await facilityService.permanentDeleteFacility(id, context);

  return sendNoContent(res);
});


module.exports = {
  listFacilities,
  getFacilityById,
  createFacility,
  updateFacility,
  deleteFacility,
  restoreFacility,
  permanentDeleteFacility
};
