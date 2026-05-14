/**
 * Visit queue controller
 *
 * @module modules/visit-queue/controllers
 * @description Handles HTTP requests for visit queue endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const visitQueueService = require('@services/visit-queue/visit-queue.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const GLOBAL_SCOPE_ROLES = new Set(['SUPER_ADMIN', 'APP_ADMIN', 'SYSTEM_ADMIN', 'PLATFORM_ADMIN']);

const normalizeScopeValue = (value) => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const hasGlobalScopeAccess = (user = {}) => {
  const roles = [
    ...(Array.isArray(user.roles) ? user.roles : []),
    user.role,
  ]
    .map((role) => String(role || '').trim().toUpperCase())
    .filter(Boolean);

  return roles.some((role) => GLOBAL_SCOPE_ROLES.has(role));
};

const buildVisitQueueScope = (req = {}) => {
  const queryTenantId = normalizeScopeValue(req.query?.tenant_id);
  const queryFacilityId = normalizeScopeValue(req.query?.facility_id);
  const bodyTenantId = normalizeScopeValue(req.body?.tenant_id);
  const bodyFacilityId = normalizeScopeValue(req.body?.facility_id);
  const userTenantId = normalizeScopeValue(req.user?.tenant_id);
  const userFacilityId = normalizeScopeValue(req.user?.facility_id);

  const isGlobalUser = hasGlobalScopeAccess(req.user);
  const tenantId = isGlobalUser ? (bodyTenantId || queryTenantId) : (userTenantId || bodyTenantId || queryTenantId);
  const facilityId = isGlobalUser ? (bodyFacilityId || queryFacilityId) : (userFacilityId || bodyFacilityId || queryFacilityId);

  return {
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(facilityId ? { facility_id: facilityId } : {}),
  };
};

/**
 * List visit queue entries with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listVisitQueues = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc',
    tenant_id,
    facility_id,
    patient_id,
    appointment_id,
    provider_user_id,
    status,
    search,
  } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (patient_id) filters.patient_id = patient_id;
  if (appointment_id) filters.appointment_id = appointment_id;
  if (provider_user_id) filters.provider_user_id = provider_user_id;
  if (status) filters.status = status;
  if (search) filters.search = search;
  Object.assign(filters, buildVisitQueueScope(req));

  const result = await visitQueueService.listVisitQueues(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.visit_queue.list.success',
    result.entries,
    result.pagination
  );
});

/**
 * Get visit queue entry by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getVisitQueueById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const entry = await visitQueueService.getVisitQueueById(id);

  return sendSuccess(res, 200, 'messages.visit_queue.get.success', entry);
});

/**
 * Create visit queue entry
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createVisitQueue = asyncHandler(async (req, res) => {
  const scope = buildVisitQueueScope(req);
  const data = {
    ...req.body,
    tenant_id: scope.tenant_id ?? req.body?.tenant_id ?? null,
    facility_id: scope.facility_id ?? req.body?.facility_id ?? null,
  };
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const entry = await visitQueueService.createVisitQueue(data, context);

  return sendSuccess(res, 201, 'messages.visit_queue.create.success', entry);
});

/**
 * Update visit queue entry
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateVisitQueue = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const scope = buildVisitQueueScope(req);
  const data = {
    ...req.body,
    ...(scope.facility_id && Object.prototype.hasOwnProperty.call(req.body || {}, 'facility_id')
      ? { facility_id: scope.facility_id }
      : {}),
  };
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const entry = await visitQueueService.updateVisitQueue(id, data, context);

  return sendSuccess(res, 200, 'messages.visit_queue.update.success', entry);
});

/**
 * Delete visit queue entry
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteVisitQueue = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await visitQueueService.deleteVisitQueue(id, context);

  return sendNoContent(res);
});

/**
 * Prioritize visit queue entry
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const prioritizeVisitQueue = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason, status } = req.body;

  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const entry = await visitQueueService.prioritizeVisitQueue(id, { reason, status }, context);

  return sendSuccess(res, 200, 'messages.visit_queue.prioritize.success', entry);
});

module.exports = {
  listVisitQueues,
  getVisitQueueById,
  createVisitQueue,
  updateVisitQueue,
  deleteVisitQueue,
  prioritizeVisitQueue
};
