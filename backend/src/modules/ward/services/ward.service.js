/**
 * Ward service
 *
 * @module modules/ward/services
 * @description Business logic for ward operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const wardRepository = require('@repositories/ward/ward.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { publishCrudRealtimeEvent, FACILITY_LAYOUT_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');

const FACILITY_LAYOUT_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.NURSE
]);

const publishFacilityLayoutRealtimeEvent = async (resource, resourceType, actorUserId, payload = {}) => {
  await publishCrudRealtimeEvent({
    event: FACILITY_LAYOUT_EVENTS.FACILITY_LAYOUT_UPDATED,
    resource,
    resource_type: resourceType,
    actor_user_id: actorUserId,
    recipient_roles: FACILITY_LAYOUT_RECIPIENT_ROLES,
    affected: {
      ward_id: resource?.ward_id || resource?.id || null,
      room_id: resource?.room_id || null
    },
    payload: {
      layout_entity: resourceType,
      ...payload
    }
  });
};

const emptyListResult = (page, limit) => ({
  wards: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveWardId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'ward',
      identifier: normalized,
      includeDeleted: true,
    });
    return resolved || normalized;
  }

  return resolveEntityId({
    model: 'ward',
    identifier: normalized,
    where: { deleted_at: null },
  });
};

const resolveWardFilterId = async (filters, field, model) => {
  if (!filters?.[field]) return undefined;
  const resolved = await resolveIdentifierForFilter({
    value: filters[field],
    model,
    where: { deleted_at: null },
  });
  if (resolved === null) return null;
  return resolved;
};

const normalizeCreatePayload = async (data = {}) => ({
  ...data,
  tenant_id: await resolveIdentifierForPayload({
    value: data.tenant_id,
    model: 'tenant',
    field: 'tenant_id',
    where: { deleted_at: null },
  }),
  facility_id: await resolveIdentifierForPayload({
    value: data.facility_id,
    model: 'facility',
    field: 'facility_id',
    where: { deleted_at: null },
  }),
  department_id: await resolveIdentifierForPayload({
    value: data.department_id,
    model: 'department',
    field: 'department_id',
    where: { deleted_at: null },
    nullable: true,
  }),
});

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      where: { deleted_at: null },
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
    payload.department_id = await resolveIdentifierForPayload({
      value: data.department_id,
      model: 'department',
      field: 'department_id',
      where: { deleted_at: null },
      nullable: true,
    });
  }

  return payload;
};

/**
 * List wards with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {string} [filters.department_id] - Filter by department ID
 * @param {string} [filters.ward_type] - Filter by ward type
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated wards
 */
const listWards = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const includeDeleted =
    filters.include_deleted === true || filters.include_deleted === 'true';
  const repoFilters = {};

  const tenantId = await resolveWardFilterId(filters, 'tenant_id', 'tenant');
  if (filters.tenant_id && tenantId === null) return emptyListResult(page, limit);
  if (tenantId) repoFilters.tenant_id = tenantId;

  const facilityId = await resolveWardFilterId(filters, 'facility_id', 'facility');
  if (filters.facility_id && facilityId === null) return emptyListResult(page, limit);
  if (facilityId) repoFilters.facility_id = facilityId;

  const departmentId = await resolveWardFilterId(filters, 'department_id', 'department');
  if (filters.department_id && departmentId === null) return emptyListResult(page, limit);
  if (departmentId) repoFilters.department_id = departmentId;

  if (filters.ward_type) {
    repoFilters.ward_type = filters.ward_type;
  }

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  // Handle search filter
  if (filters.search) {
    repoFilters.name = { contains: filters.search, mode: 'insensitive' };
  }

  // Calculate pagination
  const skip = (page - 1) * limit;

  // Build sort order
  const orderBy = includeDeleted
    ? [{ deleted_at: 'asc' }, { [sort_by]: order }]
    : { [sort_by]: order };
  const listOptions = { includeDeleted };

  // Fetch wards and count
  const [wards, total] = await Promise.all([
    wardRepository.findMany(repoFilters, skip, limit, orderBy, listOptions),
    wardRepository.count(repoFilters, listOptions)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    wards,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage
    }
  };
};

/**
 * Get ward by ID
 *
 * @param {string} id - Ward ID
 * @returns {Promise<Object>} Ward data
 */
const getWardById = async (id) => {
  const resolvedId = await resolveWardId(id);
  const ward = await wardRepository.findById(resolvedId);
  
  if (!ward) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  return ward;
};

/**
 * Get beds for a ward
 *
 * @param {string} wardId - Ward ID
 * @returns {Promise<Object>} Ward with beds
 */
const getWardBeds = async (wardId) => {
  const resolvedId = await resolveWardId(wardId);
  const ward = await wardRepository.findById(resolvedId);
  
  if (!ward) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  return ward;
};

/**
 * Create new ward
 *
 * @param {Object} data - Ward data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} data.facility_id - Facility ID
 * @param {string} [data.department_id] - Department ID
 * @param {string} data.name - Ward name
 * @param {string} data.ward_type - Ward type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created ward
 */
const createWard = async (data, context = {}) => {
  const payload = await normalizeCreatePayload(data);
  const ward = await wardRepository.create(payload);

  // Create audit log
  await createAuditLog({
    action: 'WARD_CREATED',
    entity: 'ward',
    entity_id: ward.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ward.tenant_id,
      facility_id: ward.facility_id,
      department_id: ward.department_id,
      name: ward.name,
      ward_type: ward.ward_type,
      is_active: ward.is_active
    }
  });

  await publishFacilityLayoutRealtimeEvent(ward, 'ward', context.user_id, {
    operation: 'created',
    name: ward.name,
    ward_type: ward.ward_type
  });

  return ward;
};

/**
 * Update ward
 *
 * @param {string} id - Ward ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.department_id] - Department ID
 * @param {string} [data.name] - Ward name
 * @param {string} [data.ward_type] - Ward type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated ward
 */
const updateWard = async (id, data, context = {}) => {
  const resolvedId = await resolveWardId(id);
  const beforeWard = await wardRepository.findById(resolvedId);

  if (!beforeWard) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  const payload = await normalizeUpdatePayload(data);
  const ward = await wardRepository.update(beforeWard.id, payload);

  // Create audit log
  await createAuditLog({
    action: 'WARD_UPDATED',
    entity: 'ward',
    entity_id: beforeWard.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeWard.facility_id,
        department_id: beforeWard.department_id,
        name: beforeWard.name,
        ward_type: beforeWard.ward_type,
        is_active: beforeWard.is_active
      },
      after: {
        facility_id: ward.facility_id,
        department_id: ward.department_id,
        name: ward.name,
        ward_type: ward.ward_type,
        is_active: ward.is_active
      }
    }
  });

  await publishFacilityLayoutRealtimeEvent(ward, 'ward', context.user_id, {
    operation: 'updated',
    name: ward.name,
    ward_type: ward.ward_type
  });

  return ward;
};

/**
 * Delete ward (soft delete)
 *
 * @param {string} id - Ward ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteWard = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const resolvedId = await resolveWardId(normalizedId);
  const ward = await wardRepository.findById(resolvedId);

  if (!ward) {
    const lookupIds = [...new Set([resolvedId, normalizedId].filter(Boolean))];
    for (const candidate of lookupIds) {
      const deletedWard = await resolveModelRecordByIdentifier({
        model: 'ward',
        identifier: candidate,
        includeDeleted: true,
        select: { id: true, deleted_at: true },
      });
      if (deletedWard?.deleted_at) {
        return;
      }
    }
    throw new HttpError('errors.ward.not_found', 404);
  }

  await wardRepository.softDelete(ward.id);

  await createAuditLog({
    action: 'WARD_DELETED',
    entity: 'ward',
    entity_id: ward.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ward.tenant_id,
      facility_id: ward.facility_id,
      department_id: ward.department_id,
      name: ward.name,
      ward_type: ward.ward_type
    }
  });

  await publishFacilityLayoutRealtimeEvent(ward, 'ward', context.user_id, {
    operation: 'deleted',
    name: ward.name,
    ward_type: ward.ward_type
  });
};

/**
 * Restore soft-deleted ward
 */
const restoreWard = async (id, context = {}) => {
  const wardId = await resolveWardId(id, { includeDeleted: true });
  const ward = await wardRepository.restore(wardId);

  await createAuditLog({
    action: 'WARD_RESTORED',
    entity: 'ward',
    entity_id: wardId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ward.tenant_id,
      facility_id: ward.facility_id,
      department_id: ward.department_id,
      name: ward.name,
      ward_type: ward.ward_type,
    },
  });

  await publishFacilityLayoutRealtimeEvent(ward, 'ward', context.user_id, {
    operation: 'restored',
    name: ward.name,
    ward_type: ward.ward_type,
  });

  return ward;
};

module.exports = {
  listWards,
  getWardById,
  getWardBeds,
  createWard,
  updateWard,
  deleteWard,
  restoreWard,
};
