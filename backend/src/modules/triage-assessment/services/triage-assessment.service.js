/**
 * Triage assessment service
 *
 * @module modules/triage-assessment/services
 * @description Business logic layer for triage assessment operations.
 * Per module-creation.mdc: Only import and use its own repository.
 * Per module-creation.mdc: All mutations must call audit log.
 */

const triageAssessmentRepository = require('@modules/triage-assessment/repositories/triage-assessment.repository');
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

const TRIAGE_LEVEL_ALIAS_MAP = Object.freeze({
  LEVEL_1: 'LEVEL_1',
  LEVEL_2: 'LEVEL_2',
  LEVEL_3: 'LEVEL_3',
  LEVEL_4: 'LEVEL_4',
  LEVEL_5: 'LEVEL_5',
  IMMEDIATE: 'LEVEL_1',
  URGENT: 'LEVEL_2',
  LESS_URGENT: 'LEVEL_3',
  NON_URGENT: 'LEVEL_4',
});

const normalizeTriageLevel = (value) => {
  const normalized = sanitizeIdentifier(value).toUpperCase();
  if (!normalized) return null;
  return TRIAGE_LEVEL_ALIAS_MAP[normalized] || null;
};

const buildEmptyListResult = (page, limit) => ({
  items: [],
  total: 0,
  page,
  limit,
  totalPages: 0,
});

const mapTriageAssessmentForDisplay = (record) => {
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

const resolveTriageAssessmentId = async (id) => {
  const normalized = sanitizeIdentifier(id);
  if (!normalized) return normalized;

  const resolvedId = await resolveModelIdByIdentifier({
    model: 'triage_assessment',
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

  if (filters.triage_level !== undefined) {
    const mappedTriageLevel = normalizeTriageLevel(filters.triage_level);
    if (!mappedTriageLevel) return buildEmptyListResult(page, limit);
    resolvedFilters.triage_level = mappedTriageLevel;
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
  const mappedTriageLevel = normalizeTriageLevel(payload.triage_level);
  if (!mappedTriageLevel) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'triage_level' }]);
  }
  payload.triage_level = mappedTriageLevel;
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

  if (payload.triage_level !== undefined) {
    const mappedTriageLevel = normalizeTriageLevel(payload.triage_level);
    if (!mappedTriageLevel) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'triage_level' }]);
    }
    payload.triage_level = mappedTriageLevel;
  }

  return payload;
};

/**
 * List triage assessments with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated triage assessments
 */
const listTriageAssessments = async (
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
    triageAssessmentRepository.findMany(resolvedFilters, skip, limit, orderBy),
    triageAssessmentRepository.count(resolvedFilters),
  ]);

  return {
    items: items.map(mapTriageAssessmentForDisplay),
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
};

/**
 * Get triage assessment by ID
 *
 * @param {string} id - Triage assessment ID
 * @returns {Promise<Object>} Triage assessment object
 * @throws {HttpError} If triage assessment not found
 */
const getTriageAssessmentById = async (id) => {
  const resolvedId = await resolveTriageAssessmentId(id);
  const triageAssessment = await triageAssessmentRepository.findById(resolvedId);

  if (!triageAssessment) {
    throw new HttpError('errors.triage_assessment.not_found', 404);
  }

  return mapTriageAssessmentForDisplay(triageAssessment);
};

/**
 * Create new triage assessment
 *
 * @param {Object} data - Triage assessment data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Created triage assessment
 */
const createTriageAssessment = async (data, user) => {
  const payload = await resolveCreatePayload(data);
  const triageAssessment = await triageAssessmentRepository.create(payload);

  await createAuditLog({
    action: 'CREATE',
    resource: 'triage_assessment',
    resource_id: triageAssessment.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    details: { data: payload },
  });

  return mapTriageAssessmentForDisplay(triageAssessment);
};

/**
 * Update triage assessment
 *
 * @param {string} id - Triage assessment ID
 * @param {Object} data - Update data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Updated triage assessment
 * @throws {HttpError} If triage assessment not found
 */
const updateTriageAssessment = async (id, data, user) => {
  const resolvedId = await resolveTriageAssessmentId(id);
  const existing = await triageAssessmentRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.triage_assessment.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data);
  const updated = await triageAssessmentRepository.update(existing.id, payload);

  await createAuditLog({
    action: 'UPDATE',
    resource: 'triage_assessment',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    details: { before: existing, after: payload },
  });

  return mapTriageAssessmentForDisplay(updated);
};

/**
 * Delete triage assessment (soft delete)
 *
 * @param {string} id - Triage assessment ID
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Deleted triage assessment
 * @throws {HttpError} If triage assessment not found
 */
const deleteTriageAssessment = async (id, user) => {
  const resolvedId = await resolveTriageAssessmentId(id);
  const existing = await triageAssessmentRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.triage_assessment.not_found', 404);
  }

  const deleted = await triageAssessmentRepository.softDelete(existing.id);

  await createAuditLog({
    action: 'DELETE',
    resource: 'triage_assessment',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    details: { data: existing },
  });

  return mapTriageAssessmentForDisplay(deleted);
};

module.exports = {
  listTriageAssessments,
  getTriageAssessmentById,
  createTriageAssessment,
  updateTriageAssessment,
  deleteTriageAssessment,
};
