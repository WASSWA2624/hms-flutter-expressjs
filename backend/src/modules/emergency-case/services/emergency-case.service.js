/**
 * Emergency case service
 *
 * @module modules/emergency-case/services
 * @description Business logic layer for emergency case operations.
 * Per module-creation.mdc: Only import and use its own repository.
 * Per module-creation.mdc: All mutations must call audit log.
 */

const emergencyCaseRepository = require('@repositories/emergency-case/emergency-case.repository');
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

const EMERGENCY_CASE_STATUS_ALIAS_MAP = Object.freeze({
  OPEN: 'OPEN',
  CLOSED: 'CLOSED',
  CANCELLED: 'CANCELLED',
  PENDING: 'OPEN',
  IN_PROGRESS: 'OPEN',
  COMPLETED: 'CLOSED',
});

const normalizeEmergencyCaseStatus = (value) => {
  const normalized = sanitizeIdentifier(value).toUpperCase();
  if (!normalized) return null;
  return EMERGENCY_CASE_STATUS_ALIAS_MAP[normalized] || null;
};

const buildEmptyListResult = (page, limit) => ({
  items: [],
  total: 0,
  page,
  limit,
  totalPages: 0,
});

const mapEmergencyCaseForDisplay = (record) => {
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
    patient_display_id: resolveDisplayIdentifier(
      record.patient_display_id,
      record.patient?.human_friendly_id,
      record.patient_id
    ),
    patient_display_name: record.patient_display_name || resolvePatientDisplayName(record.patient),
  };
};

const resolveEmergencyCaseId = async (id) => {
  const normalized = sanitizeIdentifier(id);
  if (!normalized) return normalized;

  const resolvedId = await resolveModelIdByIdentifier({
    model: 'emergency_case',
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

  if (filters.patient_id !== undefined) {
    const patientId = await resolveIdentifierForFilter({
      value: filters.patient_id,
      model: 'patient',
      where: {
        ...(resolvedFilters.tenant_id ? { tenant_id: resolvedFilters.tenant_id } : {}),
        ...(resolvedFilters.facility_id ? { facility_id: resolvedFilters.facility_id } : {}),
      },
    });
    if (patientId === null) return buildEmptyListResult(page, limit);
    if (patientId !== undefined) resolvedFilters.patient_id = patientId;
  }

  if (filters.severity) resolvedFilters.severity = filters.severity;
  if (filters.status !== undefined) {
    const mappedStatus = normalizeEmergencyCaseStatus(filters.status);
    if (!mappedStatus) return buildEmptyListResult(page, limit);
    resolvedFilters.status = mappedStatus;
  }

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
  const patientId = await resolveIdentifierForPayload({
    value: payload.patient_id,
    field: 'patient_id',
    model: 'patient',
    where: {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
  });

  payload.tenant_id = tenantId;
  if (facilityId !== undefined) {
    payload.facility_id = facilityId;
  } else {
    delete payload.facility_id;
  }
  payload.patient_id = patientId;

  const mappedStatus = normalizeEmergencyCaseStatus(payload.status);
  if (!mappedStatus) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
  }
  payload.status = mappedStatus;

  return payload;
};

const resolveUpdatePayload = async (data = {}, existing = null) => {
  const payload = { ...data };
  const tenantId = existing?.tenant_id || null;

  const hasFacilityField = Object.prototype.hasOwnProperty.call(payload, 'facility_id');
  if (hasFacilityField) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
  }

  if (payload.patient_id !== undefined) {
    const effectiveFacilityId = hasFacilityField ? payload.facility_id : existing?.facility_id || null;
    payload.patient_id = await resolveIdentifierForPayload({
      value: payload.patient_id,
      field: 'patient_id',
      model: 'patient',
      where: {
        ...(tenantId ? { tenant_id: tenantId } : {}),
        ...(effectiveFacilityId ? { facility_id: effectiveFacilityId } : {}),
      },
    });
  }

  if (payload.status !== undefined) {
    const mappedStatus = normalizeEmergencyCaseStatus(payload.status);
    if (!mappedStatus) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
    }
    payload.status = mappedStatus;
  }

  return payload;
};

/**
 * List emergency cases with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated emergency cases
 */
const listEmergencyCases = async (
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
    emergencyCaseRepository.findMany(resolvedFilters, skip, limit, orderBy),
    emergencyCaseRepository.count(resolvedFilters),
  ]);

  return {
    items: items.map(mapEmergencyCaseForDisplay),
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
};

/**
 * Get emergency case by ID
 *
 * @param {string} id - Emergency case ID
 * @returns {Promise<Object>} Emergency case object
 * @throws {HttpError} If emergency case not found
 */
const getEmergencyCaseById = async (id) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const emergencyCase = await emergencyCaseRepository.findById(resolvedId);

  if (!emergencyCase) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  return mapEmergencyCaseForDisplay(emergencyCase);
};

/**
 * Create new emergency case
 *
 * @param {Object} data - Emergency case data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Created emergency case
 */
const createEmergencyCase = async (data, user) => {
  const payload = await resolveCreatePayload(data);
  const emergencyCase = await emergencyCaseRepository.create(payload);

  await createAuditLog({
    action: 'CREATE',
    resource: 'emergency_case',
    resource_id: emergencyCase.id,
    user_id: user.id,
    tenant_id: emergencyCase.tenant_id || payload.tenant_id,
    details: { data: payload },
  });

  return mapEmergencyCaseForDisplay(emergencyCase);
};

/**
 * Update emergency case
 *
 * @param {string} id - Emergency case ID
 * @param {Object} data - Update data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Updated emergency case
 * @throws {HttpError} If emergency case not found
 */
const updateEmergencyCase = async (id, data, user) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const existing = await emergencyCaseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data, existing);
  const updated = await emergencyCaseRepository.update(existing.id, payload);

  await createAuditLog({
    action: 'UPDATE',
    resource: 'emergency_case',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: existing.tenant_id,
    details: { before: existing, after: payload },
  });

  return mapEmergencyCaseForDisplay(updated);
};

/**
 * Delete emergency case (soft delete)
 *
 * @param {string} id - Emergency case ID
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Deleted emergency case
 * @throws {HttpError} If emergency case not found
 */
const deleteEmergencyCase = async (id, user) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const existing = await emergencyCaseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  const deleted = await emergencyCaseRepository.softDelete(existing.id);

  await createAuditLog({
    action: 'DELETE',
    resource: 'emergency_case',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: existing.tenant_id,
    details: { data: existing },
  });

  return mapEmergencyCaseForDisplay(deleted);
};

module.exports = {
  listEmergencyCases,
  getEmergencyCaseById,
  createEmergencyCase,
  updateEmergencyCase,
  deleteEmergencyCase,
};
