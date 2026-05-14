/**
 * ICU Observation service
 *
 * @module modules/icu-observation/services
 * @description Business logic layer for ICU observation operations.
 */

const icuObservationRepository = require('@repositories/icu-observation/icu-observation.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const UUID_LIKE_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const sanitize = (value) => String(value || '').trim();
const toPublicId = (value) => {
  const normalized = sanitize(value);
  if (!normalized || UUID_LIKE_REGEX.test(normalized)) return null;
  return normalized;
};
const resolvePublicIdentifier = (record) =>
  toPublicId(record?.human_friendly_id || record?.display_id || record?.id);
const resolvePatientDisplayName = (patient) =>
  [sanitize(patient?.first_name), sanitize(patient?.last_name)]
    .filter(Boolean)
    .join(' ')
    .trim() || null;

const ICU_OBSERVATION_INCLUDE = {
  icu_stay: {
    select: {
      id: true,
      human_friendly_id: true,
      admission: {
        select: {
          id: true,
          tenant_id: true,
          human_friendly_id: true,
          patient: {
            select: {
              id: true,
              human_friendly_id: true,
              first_name: true,
              last_name: true,
            },
          },
        },
      },
    },
  },
};

const mapIcuStayRelation = (stay) => {
  if (!stay) return null;
  return {
    id: resolvePublicIdentifier(stay),
    display_id: resolvePublicIdentifier(stay),
    human_friendly_id: resolvePublicIdentifier(stay),
    admission: stay.admission
      ? {
          id: resolvePublicIdentifier(stay.admission),
          display_id: resolvePublicIdentifier(stay.admission),
          human_friendly_id: resolvePublicIdentifier(stay.admission),
          patient_display_id: resolvePublicIdentifier(stay.admission.patient),
          patient_display_name: resolvePatientDisplayName(
            stay.admission.patient
          ),
          patient: stay.admission.patient
            ? {
                id: resolvePublicIdentifier(stay.admission.patient),
                display_id: resolvePublicIdentifier(stay.admission.patient),
                human_friendly_id: resolvePublicIdentifier(
                  stay.admission.patient
                ),
                first_name: stay.admission.patient.first_name || null,
                last_name: stay.admission.patient.last_name || null,
              }
            : null,
        }
      : null,
  };
};

const mapIcuObservationRecord = (record) => {
  if (!record) return record;
  return {
    id: resolvePublicIdentifier(record),
    display_id: resolvePublicIdentifier(record),
    human_friendly_id: resolvePublicIdentifier(record),
    icu_stay_id: resolvePublicIdentifier(record.icu_stay),
    icu_stay_display_id: resolvePublicIdentifier(record.icu_stay),
    admission_display_id: resolvePublicIdentifier(record.icu_stay?.admission),
    patient_display_id: resolvePublicIdentifier(record.icu_stay?.admission?.patient),
    patient_display_name: resolvePatientDisplayName(record.icu_stay?.admission?.patient),
    observed_at: record.observed_at || null,
    observation: record.observation || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    icu_stay: mapIcuStayRelation(record.icu_stay),
  };
};

const buildEmptyPagination = (page, limit) => ({
  page,
  limit,
  total: 0,
  totalPages: 0,
  hasNextPage: false,
  hasPreviousPage: page > 1,
});

const resolveIcuObservation = async (identifier) =>
  resolveModelIdByIdentifier({
    model: 'icu_observation',
    identifier,
    select: { id: true },
  });

const resolveIcuStay = async (identifier) =>
  resolveModelIdByIdentifier({
    model: 'icu_stay',
    identifier,
    select: {
      id: true,
      admission: { select: { tenant_id: true } },
    },
  });

const resolveAuditTenantId = (record, fallback = null) =>
  record?.icu_stay?.admission?.tenant_id || fallback || null;

const listIcuObservations = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    if (filters.icu_stay_id) {
      const resolvedIcuStay = await resolveIcuStay(filters.icu_stay_id);
      if (!resolvedIcuStay?.id) {
        return {
          icu_observations: [],
          pagination: buildEmptyPagination(page, limit),
        };
      }
      whereClause.icu_stay_id = resolvedIcuStay.id;
    }

    if (filters.observed_at_from || filters.observed_at_to) {
      whereClause.observed_at = {};
      if (filters.observed_at_from) {
        whereClause.observed_at.gte = new Date(filters.observed_at_from);
      }
      if (filters.observed_at_to) {
        whereClause.observed_at.lte = new Date(filters.observed_at_to);
      }
    }

    if (filters.search) {
      whereClause.observation = { contains: filters.search };
    }

    const [icuObservations, total] = await Promise.all([
      icuObservationRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        ICU_OBSERVATION_INCLUDE
      ),
      icuObservationRepository.count(whereClause),
    ]);

    return {
      icu_observations: icuObservations.map(mapIcuObservationRecord),
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
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const getIcuObservationById = async (id) => {
  try {
    const resolvedIcuObservation = await resolveIcuObservation(id);
    if (!resolvedIcuObservation?.id) {
      throw new HttpError('errors.icu_observation.not_found', 404);
    }

    const icuObservation = await icuObservationRepository.findById(
      resolvedIcuObservation.id,
      ICU_OBSERVATION_INCLUDE
    );
    if (!icuObservation) {
      throw new HttpError('errors.icu_observation.not_found', 404);
    }

    return mapIcuObservationRecord(icuObservation);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const createIcuObservation = async (data, userId, ipAddress) => {
  try {
    const resolvedIcuStay = await resolveIcuStay(data?.icu_stay_id);
    if (!resolvedIcuStay?.id) {
      throw new HttpError('errors.icu_stay.not_found', 404, [
        { field: 'icu_stay_id' },
      ]);
    }

    const createdIcuObservation = await icuObservationRepository.create({
      ...data,
      icu_stay_id: resolvedIcuStay.id,
    });
    const icuObservation =
      (await icuObservationRepository.findById(
        createdIcuObservation.id,
        ICU_OBSERVATION_INCLUDE
      )) || createdIcuObservation;

    createAuditLog({
      tenant_id: resolveAuditTenantId(
        icuObservation,
        resolvedIcuStay.admission?.tenant_id
      ),
      user_id: userId,
      action: 'CREATE',
      entity: 'icu_observation',
      entity_id: icuObservation.id,
      diff: { after: icuObservation },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapIcuObservationRecord(icuObservation);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const updateIcuObservation = async (id, data, userId, ipAddress) => {
  try {
    const resolvedIcuObservation = await resolveIcuObservation(id);
    if (!resolvedIcuObservation?.id) {
      throw new HttpError('errors.icu_observation.not_found', 404);
    }

    const before = await icuObservationRepository.findById(
      resolvedIcuObservation.id,
      ICU_OBSERVATION_INCLUDE
    );
    if (!before) {
      throw new HttpError('errors.icu_observation.not_found', 404);
    }

    const updatedIcuObservation = await icuObservationRepository.update(
      resolvedIcuObservation.id,
      data
    );
    const icuObservation =
      (await icuObservationRepository.findById(
        updatedIcuObservation.id,
        ICU_OBSERVATION_INCLUDE
      )) || updatedIcuObservation;

    createAuditLog({
      tenant_id: resolveAuditTenantId(icuObservation, resolveAuditTenantId(before)),
      user_id: userId,
      action: 'UPDATE',
      entity: 'icu_observation',
      entity_id: icuObservation.id,
      diff: { before, after: icuObservation },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapIcuObservationRecord(icuObservation);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const deleteIcuObservation = async (id, userId, ipAddress) => {
  try {
    const resolvedIcuObservation = await resolveIcuObservation(id);
    if (!resolvedIcuObservation?.id) {
      throw new HttpError('errors.icu_observation.not_found', 404);
    }

    const before = await icuObservationRepository.findById(
      resolvedIcuObservation.id,
      ICU_OBSERVATION_INCLUDE
    );
    if (!before) {
      throw new HttpError('errors.icu_observation.not_found', 404);
    }

    await icuObservationRepository.softDelete(resolvedIcuObservation.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'icu_observation',
      entity_id: resolvedIcuObservation.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

module.exports = {
  listIcuObservations,
  getIcuObservationById,
  createIcuObservation,
  updateIcuObservation,
  deleteIcuObservation,
};
