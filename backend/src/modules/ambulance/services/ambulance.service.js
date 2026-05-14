/**
 * Ambulance service
 *
 * @module modules/ambulance/services
 * @description Business logic for ambulance operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const ambulanceRepository = require('@repositories/ambulance/ambulance.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const sanitizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const toPublicIdentifier = (value) => {
  const normalized = sanitizeIdentifier(value);
  if (!normalized || isUuidLike(normalized)) return null;
  return normalized;
};
const resolveDisplayIdentifier = (...values) => {
  for (const value of values) {
    const displayValue = toPublicIdentifier(value);
    if (displayValue) return displayValue;
  }
  return null;
};

const buildEmptyListResult = (page, limit) => ({
  ambulances: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapAmbulanceForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolveDisplayIdentifier(record.display_id, record.human_friendly_id, record.id),
    tenant_display_id: resolveDisplayIdentifier(record.tenant_display_id, record.tenant?.human_friendly_id, record.tenant_id),
    facility_display_id: resolveDisplayIdentifier(
      record.facility_display_id,
      record.facility?.human_friendly_id,
      record.facility_id
    ),
    ambulance_label: sanitizeIdentifier(record.identifier) || null,
  };
};

const resolveAmbulanceId = async (id) => {
  const normalized = sanitizeIdentifier(id);
  if (!normalized) return normalized;

  const resolvedId = await resolveModelIdByIdentifier({
    model: 'ambulance',
    identifier: normalized,
  });

  return resolvedId || normalized;
};

const resolveListFilters = async (filters = {}, page, limit) => {
  const resolvedFilters = {};

  if (filters.tenant_id !== undefined) {
    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
    });
    if (tenantId === null) return buildEmptyListResult(page, limit);
    if (tenantId !== undefined) resolvedFilters.tenant_id = tenantId;
  }

  if (filters.facility_id !== undefined) {
    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: resolvedFilters.tenant_id ? { tenant_id: resolvedFilters.tenant_id } : {},
    });
    if (facilityId === null) return buildEmptyListResult(page, limit);
    if (facilityId !== undefined) resolvedFilters.facility_id = facilityId;
  }

  if (filters.status) resolvedFilters.status = filters.status;

  const search = sanitizeIdentifier(filters.search);
  if (search) resolvedFilters.search = search;

  return resolvedFilters;
};

const resolveCreatePayload = async (data = {}) => {
  const payload = { ...data };

  const tenantId = await resolveIdentifierForPayload({
    value: payload.tenant_id,
    field: 'tenant_id',
    model: 'tenant',
  });
  const facilityId = await resolveIdentifierForPayload({
    value: payload.facility_id,
    field: 'facility_id',
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
    nullable: true,
  });

  payload.tenant_id = tenantId;
  payload.facility_id = facilityId;
  return payload;
};

const resolveUpdatePayload = async (data = {}, existing = null) => {
  const payload = { ...data };
  const tenantId = existing?.tenant_id || null;

  if (Object.prototype.hasOwnProperty.call(payload, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
  }

  return payload;
};

/**
 * List ambulances with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {string} [filters.status] - Filter by status
 * @param {string} [filters.search] - Search by identifier
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated ambulances
 */
const listAmbulances = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const resolvedFilters = await resolveListFilters(filters, page, limit);
  if (resolvedFilters && resolvedFilters.ambulances && resolvedFilters.pagination) {
    return resolvedFilters;
  }

  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };

  const [ambulances, total] = await Promise.all([
    ambulanceRepository.findMany(resolvedFilters, skip, limit, orderBy),
    ambulanceRepository.count(resolvedFilters),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    ambulances: ambulances.map(mapAmbulanceForDisplay),
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage,
    },
  };
};

/**
 * Get ambulance by ID
 *
 * @param {string} id - Ambulance ID
 * @returns {Promise<Object>} Ambulance data
 */
const getAmbulanceById = async (id) => {
  const resolvedId = await resolveAmbulanceId(id);
  const ambulance = await ambulanceRepository.findById(resolvedId);

  if (!ambulance) {
    throw new HttpError('errors.ambulance.not_found', 404);
  }

  return mapAmbulanceForDisplay(ambulance);
};

/**
 * Create new ambulance
 *
 * @param {Object} data - Ambulance data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} data.identifier - Ambulance identifier
 * @param {string} data.status - Ambulance status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created ambulance
 */
const createAmbulance = async (data, context = {}) => {
  const payload = await resolveCreatePayload(data);
  const ambulance = await ambulanceRepository.create(payload);

  await createAuditLog({
    action: 'AMBULANCE_CREATED',
    entity: 'ambulance',
    entity_id: ambulance.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ambulance.tenant_id,
      facility_id: ambulance.facility_id,
      identifier: ambulance.identifier,
      status: ambulance.status,
    },
  });

  return mapAmbulanceForDisplay(ambulance);
};

/**
 * Update ambulance
 *
 * @param {string} id - Ambulance ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.identifier] - Ambulance identifier
 * @param {string} [data.status] - Ambulance status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated ambulance
 */
const updateAmbulance = async (id, data, context = {}) => {
  const resolvedId = await resolveAmbulanceId(id);
  const beforeAmbulance = await ambulanceRepository.findById(resolvedId);

  if (!beforeAmbulance) {
    throw new HttpError('errors.ambulance.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data, beforeAmbulance);
  const ambulance = await ambulanceRepository.update(beforeAmbulance.id, payload);

  await createAuditLog({
    action: 'AMBULANCE_UPDATED',
    entity: 'ambulance',
    entity_id: beforeAmbulance.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeAmbulance.facility_id,
        identifier: beforeAmbulance.identifier,
        status: beforeAmbulance.status,
      },
      after: {
        facility_id: ambulance.facility_id,
        identifier: ambulance.identifier,
        status: ambulance.status,
      },
    },
  });

  return mapAmbulanceForDisplay(ambulance);
};

/**
 * Delete ambulance (soft delete)
 *
 * @param {string} id - Ambulance ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteAmbulance = async (id, context = {}) => {
  const resolvedId = await resolveAmbulanceId(id);
  const ambulance = await ambulanceRepository.findById(resolvedId);

  if (!ambulance) {
    throw new HttpError('errors.ambulance.not_found', 404);
  }

  await ambulanceRepository.softDelete(ambulance.id);

  await createAuditLog({
    action: 'AMBULANCE_DELETED',
    entity: 'ambulance',
    entity_id: ambulance.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ambulance.tenant_id,
      facility_id: ambulance.facility_id,
      identifier: ambulance.identifier,
      status: ambulance.status,
    },
  });
};

module.exports = {
  listAmbulances,
  getAmbulanceById,
  createAmbulance,
  updateAmbulance,
  deleteAmbulance,
};
