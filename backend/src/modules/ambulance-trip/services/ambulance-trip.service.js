/**
 * Ambulance Trip service
 *
 * @module modules/ambulance-trip/services
 * @description Business logic for ambulance trip operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const ambulanceTripRepository = require('@repositories/ambulance-trip/ambulance-trip.repository');
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
const resolvePatientDisplayName = (patient) => {
  const firstName = sanitizeIdentifier(patient?.first_name);
  const lastName = sanitizeIdentifier(patient?.last_name);
  const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();
  return fullName || null;
};

const parseDateField = (value, field, { allowNull = true } = {}) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (allowNull) return null;
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }
  if (value instanceof Date) {
    if (!Number.isNaN(value.getTime())) return value;
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }
  return parsed;
};

const ensureTimelineOrder = (startedAt, endedAt) => {
  if (!startedAt || !endedAt) return;
  if (endedAt.getTime() < startedAt.getTime()) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'ended_at' }]);
  }
};

const findOtherActiveTripForAmbulance = async (ambulanceId, excludedTripId = null) => {
  if (!ambulanceId) return null;

  const activeTrips = await ambulanceTripRepository.findMany(
    { ambulance_id: ambulanceId, ended_at: null },
    0,
    5,
    { created_at: 'desc' }
  );
  if (!Array.isArray(activeTrips) || activeTrips.length === 0) return null;

  return activeTrips.find((trip) => sanitizeIdentifier(trip?.id) !== sanitizeIdentifier(excludedTripId)) || null;
};

const buildEmptyListResult = (page, limit) => ({
  trips: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapAmbulanceTripForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolveDisplayIdentifier(record.display_id, record.human_friendly_id, record.id),
    ambulance_display_id: resolveDisplayIdentifier(
      record.ambulance_display_id,
      record.ambulance?.human_friendly_id,
      record.ambulance_id
    ),
    ambulance_display_label: sanitizeIdentifier(record.ambulance_display_label || record.ambulance?.identifier) || null,
    emergency_case_display_id: resolveDisplayIdentifier(
      record.emergency_case_display_id,
      record.emergency_case?.human_friendly_id,
      record.emergency_case_id
    ),
    patient_display_id: resolveDisplayIdentifier(
      record.patient_display_id,
      record.emergency_case?.patient?.human_friendly_id
    ),
    patient_display_name: record.patient_display_name || resolvePatientDisplayName(record.emergency_case?.patient),
  };
};

const resolveAmbulanceTripId = async (id) => {
  const normalized = sanitizeIdentifier(id);
  if (!normalized) return normalized;

  const resolvedId = await resolveModelIdByIdentifier({
    model: 'ambulance_trip',
    identifier: normalized,
  });

  return resolvedId || normalized;
};

const resolveListFilters = async (filters = {}, page, limit) => {
  const resolvedFilters = {};

  if (filters.ambulance_id !== undefined) {
    const ambulanceId = await resolveIdentifierForFilter({
      value: filters.ambulance_id,
      model: 'ambulance',
    });
    if (ambulanceId === null) return buildEmptyListResult(page, limit);
    if (ambulanceId !== undefined) resolvedFilters.ambulance_id = ambulanceId;
  }

  if (filters.emergency_case_id !== undefined) {
    const emergencyCaseId = await resolveIdentifierForFilter({
      value: filters.emergency_case_id,
      model: 'emergency_case',
    });
    if (emergencyCaseId === null) return buildEmptyListResult(page, limit);
    if (emergencyCaseId !== undefined) resolvedFilters.emergency_case_id = emergencyCaseId;
  }

  const search = sanitizeIdentifier(filters.search);
  if (search) resolvedFilters.search = search;

  return resolvedFilters;
};

const resolveCreatePayload = async (data = {}) => {
  const payload = { ...data };

  payload.ambulance_id = await resolveIdentifierForPayload({
    value: payload.ambulance_id,
    field: 'ambulance_id',
    model: 'ambulance',
  });
  payload.emergency_case_id = await resolveIdentifierForPayload({
    value: payload.emergency_case_id,
    field: 'emergency_case_id',
    model: 'emergency_case',
  });

  payload.started_at = parseDateField(payload.started_at, 'started_at') || new Date();
  payload.ended_at = parseDateField(payload.ended_at, 'ended_at') ?? null;
  ensureTimelineOrder(payload.started_at, payload.ended_at);

  if (payload.ended_at === null) {
    const activeTrip = await findOtherActiveTripForAmbulance(payload.ambulance_id);
    if (activeTrip) {
      throw new HttpError('errors.database.unique_field', 409, [{ field: 'ambulance_id' }]);
    }
  }

  return payload;
};

const resolveUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (payload.ambulance_id !== undefined) {
    payload.ambulance_id = await resolveIdentifierForPayload({
      value: payload.ambulance_id,
      field: 'ambulance_id',
      model: 'ambulance',
    });
  }

  if (payload.emergency_case_id !== undefined) {
    payload.emergency_case_id = await resolveIdentifierForPayload({
      value: payload.emergency_case_id,
      field: 'emergency_case_id',
      model: 'emergency_case',
    });
  }

  if (payload.started_at !== undefined) {
    payload.started_at = parseDateField(payload.started_at, 'started_at');
  }

  if (payload.ended_at !== undefined) {
    payload.ended_at = parseDateField(payload.ended_at, 'ended_at');
  }

  return payload;
};

/**
 * List ambulance trips with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.ambulance_id] - Filter by ambulance ID
 * @param {string} [filters.emergency_case_id] - Filter by emergency case ID
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated ambulance trips
 */
const listAmbulanceTrips = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const resolvedFilters = await resolveListFilters(filters, page, limit);
  if (resolvedFilters && resolvedFilters.trips && resolvedFilters.pagination) {
    return resolvedFilters;
  }

  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };

  const [trips, total] = await Promise.all([
    ambulanceTripRepository.findMany(resolvedFilters, skip, limit, orderBy),
    ambulanceTripRepository.count(resolvedFilters),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    trips: trips.map(mapAmbulanceTripForDisplay),
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
 * Get ambulance trip by ID
 *
 * @param {string} id - Ambulance Trip ID
 * @returns {Promise<Object>} Ambulance Trip data
 */
const getAmbulanceTripById = async (id) => {
  const resolvedId = await resolveAmbulanceTripId(id);
  const trip = await ambulanceTripRepository.findById(resolvedId);

  if (!trip) {
    throw new HttpError('errors.ambulance_trip.not_found', 404);
  }

  return mapAmbulanceTripForDisplay(trip);
};

/**
 * Create new ambulance trip
 *
 * @param {Object} data - Ambulance Trip data
 * @param {string} data.ambulance_id - Ambulance ID
 * @param {string} data.emergency_case_id - Emergency Case ID
 * @param {string} [data.started_at] - Started at timestamp
 * @param {string} [data.ended_at] - Ended at timestamp
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created ambulance trip
 */
const createAmbulanceTrip = async (data, context = {}) => {
  const payload = await resolveCreatePayload(data);
  const trip = await ambulanceTripRepository.create(payload);

  await createAuditLog({
    action: 'AMBULANCE_TRIP_CREATED',
    entity: 'ambulance_trip',
    entity_id: trip.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      ambulance_id: trip.ambulance_id,
      emergency_case_id: trip.emergency_case_id,
      started_at: trip.started_at,
      ended_at: trip.ended_at,
    },
  });

  return mapAmbulanceTripForDisplay(trip);
};

/**
 * Update ambulance trip
 *
 * @param {string} id - Ambulance Trip ID
 * @param {Object} data - Update data
 * @param {string} [data.ambulance_id] - Ambulance ID
 * @param {string} [data.emergency_case_id] - Emergency Case ID
 * @param {string} [data.started_at] - Started at timestamp
 * @param {string} [data.ended_at] - Ended at timestamp
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated ambulance trip
 */
const updateAmbulanceTrip = async (id, data, context = {}) => {
  const resolvedId = await resolveAmbulanceTripId(id);
  const beforeTrip = await ambulanceTripRepository.findById(resolvedId);

  if (!beforeTrip) {
    throw new HttpError('errors.ambulance_trip.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data);
  const effectiveAmbulanceId = payload.ambulance_id || beforeTrip.ambulance_id;
  const effectiveStartedAt =
    payload.started_at !== undefined ? payload.started_at : beforeTrip.started_at || null;
  const effectiveEndedAt =
    payload.ended_at !== undefined ? payload.ended_at : beforeTrip.ended_at || null;
  ensureTimelineOrder(effectiveStartedAt, effectiveEndedAt);

  if (effectiveEndedAt === null) {
    const activeTrip = await findOtherActiveTripForAmbulance(effectiveAmbulanceId, beforeTrip.id);
    if (activeTrip) {
      throw new HttpError('errors.database.unique_field', 409, [{ field: 'ambulance_id' }]);
    }
  }

  const trip = await ambulanceTripRepository.update(beforeTrip.id, payload);

  await createAuditLog({
    action: 'AMBULANCE_TRIP_UPDATED',
    entity: 'ambulance_trip',
    entity_id: beforeTrip.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        ambulance_id: beforeTrip.ambulance_id,
        emergency_case_id: beforeTrip.emergency_case_id,
        started_at: beforeTrip.started_at,
        ended_at: beforeTrip.ended_at,
      },
      after: {
        ambulance_id: trip.ambulance_id,
        emergency_case_id: trip.emergency_case_id,
        started_at: trip.started_at,
        ended_at: trip.ended_at,
      },
    },
  });

  return mapAmbulanceTripForDisplay(trip);
};

/**
 * Delete ambulance trip (soft delete)
 *
 * @param {string} id - Ambulance Trip ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteAmbulanceTrip = async (id, context = {}) => {
  const resolvedId = await resolveAmbulanceTripId(id);
  const trip = await ambulanceTripRepository.findById(resolvedId);

  if (!trip) {
    throw new HttpError('errors.ambulance_trip.not_found', 404);
  }

  await ambulanceTripRepository.softDelete(trip.id);

  await createAuditLog({
    action: 'AMBULANCE_TRIP_DELETED',
    entity: 'ambulance_trip',
    entity_id: trip.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      ambulance_id: trip.ambulance_id,
      emergency_case_id: trip.emergency_case_id,
      started_at: trip.started_at,
      ended_at: trip.ended_at,
    },
  });
};

module.exports = {
  listAmbulanceTrips,
  getAmbulanceTripById,
  createAmbulanceTrip,
  updateAmbulanceTrip,
  deleteAmbulanceTrip,
};
