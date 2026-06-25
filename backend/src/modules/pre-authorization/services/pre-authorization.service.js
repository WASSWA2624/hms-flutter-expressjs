/**
 * Pre-authorization service
 *
 * @module modules/pre-authorization/services
 * @description Business logic layer for pre-authorization operations.
 */

const preAuthorizationRepository = require('@repositories/pre-authorization/pre-authorization.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const PRE_AUTH_INCLUDE = {
  coverage_plan: { select: { id: true, human_friendly_id: true, tenant_id: true, name: true, provider_name: true } },
  patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
  encounter: { select: { id: true, human_friendly_id: true } },
  admission: { select: { id: true, human_friendly_id: true } },
};

const buildEmptyListResult = (page, limit) => ({
  pre_authorizations: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveTenantIdFromPreAuthorization = (record) => record?.coverage_plan?.tenant_id || null;

const mapPreAuthorizationForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    coverage_plan_display_id: resolvePublicIdentifier(
      record?.coverage_plan_display_id,
      record?.coverage_plan?.human_friendly_id,
      record?.coverage_plan_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.patient?.human_friendly_id,
      record?.patient_id
    ),
    encounter_display_id: resolvePublicIdentifier(
      record?.encounter_display_id,
      record?.encounter?.human_friendly_id,
      record?.encounter_id
    ),
    admission_display_id: resolvePublicIdentifier(
      record?.admission_display_id,
      record?.admission?.human_friendly_id,
      record?.admission_id
    ),
    timeline_at: record?.timeline_at || record?.approved_at || record?.requested_at || record?.created_at || null,
  };
};

const resolveOptionalIdentifier = async ({ value, field, model }) => {
  if (value === undefined) return undefined;
  if (value === null || String(value).trim() === '') return null;
  return resolveIdentifierForPayload({ value, field, model });
};

/**
 * List pre-authorizations with pagination and filtering
 */
const listPreAuthorizations = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan',
      });
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.patient_id !== undefined) {
      const patientId = await resolveIdentifierForFilter({
        value: filters.patient_id,
        model: 'patient',
      });
      if (patientId === null) return buildEmptyListResult(page, limit);
      if (patientId !== undefined) whereClause.patient_id = patientId;
    }

    if (filters.encounter_id !== undefined) {
      const encounterId = await resolveIdentifierForFilter({
        value: filters.encounter_id,
        model: 'encounter',
      });
      if (encounterId === null) return buildEmptyListResult(page, limit);
      if (encounterId !== undefined) whereClause.encounter_id = encounterId;
    }

    if (filters.admission_id !== undefined) {
      const admissionId = await resolveIdentifierForFilter({
        value: filters.admission_id,
        model: 'admission',
      });
      if (admissionId === null) return buildEmptyListResult(page, limit);
      if (admissionId !== undefined) whereClause.admission_id = admissionId;
    }

    if (filters.status) whereClause.status = filters.status;

    if (filters.requested_at_from || filters.requested_at_to) {
      whereClause.requested_at = {};
      if (filters.requested_at_from) whereClause.requested_at.gte = new Date(filters.requested_at_from);
      if (filters.requested_at_to) whereClause.requested_at.lte = new Date(filters.requested_at_to);
    }

    if (filters.approved_at_from || filters.approved_at_to) {
      whereClause.approved_at = {};
      if (filters.approved_at_from) whereClause.approved_at.gte = new Date(filters.approved_at_from);
      if (filters.approved_at_to) whereClause.approved_at.lte = new Date(filters.approved_at_to);
    }

    const [preAuthorizations, total] = await Promise.all([
      preAuthorizationRepository.findMany(whereClause, skip, limit, orderBy, PRE_AUTH_INCLUDE),
      preAuthorizationRepository.count(whereClause),
    ]);

    return {
      pre_authorizations: preAuthorizations.map(mapPreAuthorizationForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get pre-authorization by ID
 */
const getPreAuthorizationById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pre_authorization',
      identifier: id,
    });

    const preAuthorization = await preAuthorizationRepository.findById(resolvedId, PRE_AUTH_INCLUDE);

    if (!preAuthorization) {
      throw new HttpError('errors.pre_authorization.not_found', 404);
    }

    return mapPreAuthorizationForDisplay(preAuthorization);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new pre-authorization
 */
const createPreAuthorization = async (data, userId, ipAddress) => {
  try {
    const coveragePlanId = await resolveIdentifierForPayload({
      value: data?.coverage_plan_id,
      field: 'coverage_plan_id',
      model: 'coverage_plan',
    });

    const payload = { ...data, coverage_plan_id: coveragePlanId };
    payload.patient_id = await resolveOptionalIdentifier({
      value: data?.patient_id,
      field: 'patient_id',
      model: 'patient',
    });
    payload.encounter_id = await resolveOptionalIdentifier({
      value: data?.encounter_id,
      field: 'encounter_id',
      model: 'encounter',
    });
    payload.admission_id = await resolveOptionalIdentifier({
      value: data?.admission_id,
      field: 'admission_id',
      model: 'admission',
    });

    const preAuthorization = await preAuthorizationRepository.create(payload);

    const createdRecord = await preAuthorizationRepository.findById(preAuthorization.id, PRE_AUTH_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromPreAuthorization(createdRecord),
      user_id: userId,
      action: 'CREATE',
      entity: 'pre_authorization',
      entity_id: preAuthorization.id,
      diff: { after: preAuthorization },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapPreAuthorizationForDisplay(createdRecord || preAuthorization);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update pre-authorization
 */
const updatePreAuthorization = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pre_authorization',
      identifier: id,
    });

    const before = await preAuthorizationRepository.findById(resolvedId, PRE_AUTH_INCLUDE);

    if (!before) {
      throw new HttpError('errors.pre_authorization.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'coverage_plan_id')) {
      payload.coverage_plan_id = await resolveIdentifierForPayload({
        value: payload.coverage_plan_id,
        field: 'coverage_plan_id',
        model: 'coverage_plan',
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'patient_id')) {
      payload.patient_id = await resolveOptionalIdentifier({
        value: payload.patient_id,
        field: 'patient_id',
        model: 'patient',
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
      payload.encounter_id = await resolveOptionalIdentifier({
        value: payload.encounter_id,
        field: 'encounter_id',
        model: 'encounter',
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'admission_id')) {
      payload.admission_id = await resolveOptionalIdentifier({
        value: payload.admission_id,
        field: 'admission_id',
        model: 'admission',
      });
    }

    if (payload.status === 'APPROVED' && !payload.approved_at) {
      payload.approved_at = new Date();
    }

    const preAuthorization = await preAuthorizationRepository.update(before.id, payload);
    const updatedRecord = await preAuthorizationRepository.findById(preAuthorization.id, PRE_AUTH_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromPreAuthorization(updatedRecord) || resolveTenantIdFromPreAuthorization(before),
      user_id: userId,
      action: 'UPDATE',
      entity: 'pre_authorization',
      entity_id: preAuthorization.id,
      diff: { before, after: preAuthorization },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapPreAuthorizationForDisplay(updatedRecord || preAuthorization);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete pre-authorization (soft delete)
 */
const deletePreAuthorization = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pre_authorization',
      identifier: id,
    });

    const before = await preAuthorizationRepository.findById(resolvedId, PRE_AUTH_INCLUDE);

    if (!before) {
      throw new HttpError('errors.pre_authorization.not_found', 404);
    }

    await preAuthorizationRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: resolveTenantIdFromPreAuthorization(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'pre_authorization',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPreAuthorizations,
  getPreAuthorizationById,
  createPreAuthorization,
  updatePreAuthorization,
  deletePreAuthorization,
};
