/**
 * Emergency response service
 *
 * @module modules/emergency-response/services
 * @description Business logic layer for emergency response operations.
 * Per module-creation.mdc: Only import and use its own repository.
 * Per module-creation.mdc: All mutations must call audit log.
 */

const emergencyResponseRepository = require('@modules/emergency-response/repositories/emergency-response.repository');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
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

const buildEmptyListResult = (page, limit) => ({
  items: [],
  total: 0,
  page,
  limit,
  totalPages: 0,
});

const mapEmergencyResponseForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolveDisplayIdentifier(record.display_id, record.human_friendly_id, record.id),
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

const resolveEmergencyResponseId = async (id) => {
  const normalized = sanitizeIdentifier(id);
  if (!normalized) return normalized;

  const resolvedId = await resolveModelIdByIdentifier({
    model: 'emergency_response',
    identifier: normalized,
  });

  return resolvedId || normalized;
};

const resolveListFilters = async (filters = {}, page, limit) => {
  const resolvedFilters = {};

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
  payload.emergency_case_id = await resolveIdentifierForPayload({
    value: payload.emergency_case_id,
    field: 'emergency_case_id',
    model: 'emergency_case',
  });
  return payload;
};

const resolveUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (payload.emergency_case_id !== undefined) {
    payload.emergency_case_id = await resolveIdentifierForPayload({
      value: payload.emergency_case_id,
      field: 'emergency_case_id',
      model: 'emergency_case',
    });
  }

  return payload;
};

/**
 * List emergency responses with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated emergency responses
 */
const listEmergencyResponses = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'created_at',
  order = 'desc'
) => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  const resolvedFilters = await resolveListFilters(filters, page, limit);
  if (resolvedFilters && resolvedFilters.items && resolvedFilters.total !== undefined) {
    return resolvedFilters;
  }

  const [items, total] = await Promise.all([
    emergencyResponseRepository.findMany(resolvedFilters, skip, limit, orderBy),
    emergencyResponseRepository.count(resolvedFilters),
  ]);

  return {
    items: items.map(mapEmergencyResponseForDisplay),
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
};

/**
 * Get emergency response by ID
 *
 * @param {string} id - Emergency response ID
 * @returns {Promise<Object>} Emergency response object
 * @throws {HttpError} If emergency response not found
 */
const getEmergencyResponseById = async (id) => {
  const resolvedId = await resolveEmergencyResponseId(id);
  const emergencyResponse = await emergencyResponseRepository.findById(resolvedId);

  if (!emergencyResponse) {
    throw new HttpError('errors.emergency_response.not_found', 404);
  }

  return mapEmergencyResponseForDisplay(emergencyResponse);
};

/**
 * Create new emergency response
 *
 * @param {Object} data - Emergency response data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Created emergency response
 */
const createEmergencyResponse = async (data, user) => {
  const payload = await resolveCreatePayload(data);
  const emergencyResponse = await emergencyResponseRepository.create(payload);

  await createAuditLog({
    action: 'CREATE',
    resource: 'emergency_response',
    resource_id: emergencyResponse.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    details: { data: payload },
  });

  return mapEmergencyResponseForDisplay(emergencyResponse);
};

/**
 * Update emergency response
 *
 * @param {string} id - Emergency response ID
 * @param {Object} data - Update data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Updated emergency response
 * @throws {HttpError} If emergency response not found
 */
const updateEmergencyResponse = async (id, data, user) => {
  const resolvedId = await resolveEmergencyResponseId(id);
  const existing = await emergencyResponseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_response.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data);
  const updated = await emergencyResponseRepository.update(existing.id, payload);

  await createAuditLog({
    action: 'UPDATE',
    resource: 'emergency_response',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    details: { before: existing, after: payload },
  });

  return mapEmergencyResponseForDisplay(updated);
};

/**
 * Delete emergency response (soft delete)
 *
 * @param {string} id - Emergency response ID
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Deleted emergency response
 * @throws {HttpError} If emergency response not found
 */
const deleteEmergencyResponse = async (id, user) => {
  const resolvedId = await resolveEmergencyResponseId(id);
  const existing = await emergencyResponseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_response.not_found', 404);
  }

  const deleted = await emergencyResponseRepository.softDelete(existing.id);

  await createAuditLog({
    action: 'DELETE',
    resource: 'emergency_response',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    details: { data: existing },
  });

  return mapEmergencyResponseForDisplay(deleted);
};

module.exports = {
  listEmergencyResponses,
  getEmergencyResponseById,
  createEmergencyResponse,
  updateEmergencyResponse,
  deleteEmergencyResponse,
};
