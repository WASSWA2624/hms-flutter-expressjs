/**
 * Facility service
 *
 * @module modules/facility/services
 * @description Business logic for facility operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const facilityRepository = require('@repositories/facility/facility.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveEntityId } = require('@lib/billing/identifiers');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT } = require('@config/constants');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const { PLATFORM_ADMIN_EVENTS } = require('@lib/websocket/events');
const { ROLES } = require('@config/roles');
const {
  publishPlatformRealtimeEvent,
  buildFacilityDashboardDeltas
} = require('@lib/realtime/platform-realtime');

const FACILITY_REALTIME_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN
]);

const publishFacilityRealtimeEvent = async (
  event,
  facility,
  actorUserId,
  operation = 'create'
) => {
  await Promise.all([
    publishCrudRealtimeEvent({
      event,
      resource: facility,
      resource_type: 'facility',
      actor_user_id: actorUserId,
      recipient_roles: FACILITY_REALTIME_RECIPIENT_ROLES,
      payload: {
        is_active: facility?.is_active !== false,
        name: facility?.name || null
      }
    }),
    publishPlatformRealtimeEvent({
      event,
      resource_type: 'facility',
      resource_id: facility?.id || null,
      actor_user_id: actorUserId,
      tenant_id: facility?.tenant_id || null,
      facility_id: facility?.id || null,
      dashboard_deltas: buildFacilityDashboardDeltas(facility, operation),
      payload: {
        is_active: facility?.is_active !== false,
        name: facility?.name || null
      }
    })
  ]);
};

const resolveTenantId = async (identifier) =>
  resolveEntityId({ model: 'tenant', identifier });

const resolveFacilityId = async (identifier) =>
  resolveEntityId({ model: 'facility', identifier });

const toPositiveInt = (value, fallback, max = Number.POSITIVE_INFINITY) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  const normalized = Math.trunc(parsed);
  if (normalized <= 0) return fallback;
  return Math.min(normalized, max);
};

const normalizeSortOrder = (value) => {
  const normalized = String(value || 'desc').toLowerCase();
  return normalized === 'asc' ? 'asc' : 'desc';
};

/**
 * List facilities with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_type] - Filter by facility type
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated facilities
 */
const listFacilities = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const resolvedPage = toPositiveInt(page, DEFAULT_PAGE);
  const resolvedLimit = toPositiveInt(limit, DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT);
  const resolvedSortBy = typeof sort_by === 'string' && sort_by.trim()
    ? sort_by.trim()
    : 'created_at';
  const resolvedOrder = normalizeSortOrder(order);

  // Build repository filters
  const repoFilters = {};

  if (filters.tenant_id) {
    repoFilters.tenant_id = await resolveTenantId(filters.tenant_id);
  }

  if (filters.facility_type) {
    repoFilters.facility_type = filters.facility_type;
  }

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  // Handle search filter
  if (filters.search) {
    repoFilters.name = { contains: filters.search };
  }

  // Calculate pagination
  const skip = (resolvedPage - 1) * resolvedLimit;

  // Build sort order
  const orderBy = {};
  orderBy[resolvedSortBy] = resolvedOrder;

  // Fetch facilities and count
  const [facilities, total] = await Promise.all([
    facilityRepository.findMany(repoFilters, skip, resolvedLimit, orderBy),
    facilityRepository.count(repoFilters)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / resolvedLimit);
  const hasNextPage = resolvedPage < totalPages;
  const hasPreviousPage = resolvedPage > 1;

  return {
    facilities,
    pagination: {
      page: resolvedPage,
      limit: resolvedLimit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage
    }
  };
};

/**
 * Get facility by ID
 *
 * @param {string} id - Facility ID
 * @returns {Promise<Object>} Facility data
 */
const getFacilityById = async (id) => {
  const facilityId = await resolveFacilityId(id);
  const facility = await facilityRepository.findById(facilityId);
  
  if (!facility) {
    throw new HttpError('errors.facility.not_found', 404);
  }

  return facility;
};

/**
 * Create new facility
 *
 * @param {Object} data - Facility data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} data.name - Facility name
 * @param {string} data.facility_type - Facility type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created facility
 */
const assertUniqueFacilityName = async (tenantId, name, excludeFacilityId = null) => {
  const duplicate = await facilityRepository.findByTenantAndName(
    tenantId,
    name,
    excludeFacilityId
  );
  if (duplicate) {
    throw new HttpError('errors.facility.duplicate_name', 409);
  }
};

const createFacility = async (data, context = {}) => {
  const payload = {
    ...data,
    tenant_id: await resolveTenantId(data.tenant_id),
  };

  await assertUniqueFacilityName(payload.tenant_id, payload.name);

  // Create facility
  const facility = await facilityRepository.create(payload);

  // Create audit log
  await createAuditLog({
    action: 'FACILITY_CREATED',
    entity: 'facility',
    entity_id: facility.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: facility.tenant_id,
      name: facility.name,
      facility_type: facility.facility_type,
      is_active: facility.is_active
    }
  });

  await publishFacilityRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.FACILITY_CREATED,
    facility,
    context.user_id,
    'create'
  );

  return facility;
};
 *
 * @param {string} id - Facility ID
 * @param {Object} data - Update data
 * @param {string} [data.name] - Facility name
 * @param {string} [data.facility_type] - Facility type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated facility
 */
const updateFacility = async (id, data, context = {}) => {
  const facilityId = await resolveFacilityId(id);
  // Check if facility exists and get before state
  const beforeFacility = await facilityRepository.findById(facilityId);
  
  if (!beforeFacility) {
    throw new HttpError('errors.facility.not_found', 404);
  }

  if (data.name !== undefined) {
    await assertUniqueFacilityName(
      beforeFacility.tenant_id,
      data.name,
      facilityId
    );
  }

  // Update facility
  const facility = await facilityRepository.update(facilityId, data);

  // Create audit log
  await createAuditLog({
    action: 'FACILITY_UPDATED',
    entity: 'facility',
    entity_id: facilityId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        name: beforeFacility.name,
        facility_type: beforeFacility.facility_type,
        is_active: beforeFacility.is_active
      },
      after: {
        name: facility.name,
        facility_type: facility.facility_type,
        is_active: facility.is_active
      }
    }
  });

  await publishFacilityRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.FACILITY_UPDATED,
    facility,
    context.user_id,
    'update'
  );

  return facility;
};

/**
 * Delete facility (soft delete)
 *
 * @param {string} id - Facility ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteFacility = async (id, context = {}) => {
  const facilityId = await resolveFacilityId(id);
  // Check if facility exists
  const facility = await facilityRepository.findById(facilityId);
  
  if (!facility) {
    throw new HttpError('errors.facility.not_found', 404);
  }

  // Soft delete facility
  await facilityRepository.softDelete(facilityId);

  // Create audit log
  await createAuditLog({
    action: 'FACILITY_DELETED',
    entity: 'facility',
    entity_id: facilityId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      name: facility.name,
      facility_type: facility.facility_type
    }
  });

  await publishFacilityRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.FACILITY_DELETED,
    facility,
    context.user_id,
    'delete'
  );
};

/**
 * Get facility branches with pagination
 *
 * @param {string} facilityId - Facility ID
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated branches
 */
const getFacilityBranches = async (facilityId, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const resolvedPage = toPositiveInt(page, DEFAULT_PAGE);
  const resolvedLimit = toPositiveInt(limit, DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT);
  const resolvedSortBy = typeof sort_by === 'string' && sort_by.trim()
    ? sort_by.trim()
    : 'created_at';
  const resolvedOrder = normalizeSortOrder(order);

  const resolvedFacilityId = await resolveFacilityId(facilityId);

  // Check if facility exists
  const facility = await facilityRepository.findById(resolvedFacilityId);
  
  if (!facility) {
    throw new HttpError('errors.facility.not_found', 404);
  }

  // Calculate pagination
  const skip = (resolvedPage - 1) * resolvedLimit;

  // Build sort order
  const orderBy = {};
  orderBy[resolvedSortBy] = resolvedOrder;

  // Fetch branches and count
  const [branches, total] = await Promise.all([
    facilityRepository.findBranches(resolvedFacilityId, skip, resolvedLimit, orderBy),
    facilityRepository.countBranches(resolvedFacilityId)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / resolvedLimit);
  const hasNextPage = resolvedPage < totalPages;
  const hasPreviousPage = resolvedPage > 1;

  return {
    branches,
    pagination: {
      page: resolvedPage,
      limit: resolvedLimit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage
    }
  };
};

module.exports = {
  listFacilities,
  getFacilityById,
  createFacility,
  updateFacility,
  deleteFacility,
  getFacilityBranches
};
