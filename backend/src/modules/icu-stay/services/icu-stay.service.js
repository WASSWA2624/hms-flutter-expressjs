/**
 * ICU Stay service
 *
 * @module modules/icu-stay/services
 * @description Business logic layer for ICU stay operations.
 */

const icuStayRepository = require('@repositories/icu-stay/icu-stay.repository');
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

const ICU_STAY_INCLUDE = {
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
};

const mapAdmissionRelation = (admission) => {
  if (!admission) return null;
  const patient = admission.patient
    ? {
        id: resolvePublicIdentifier(admission.patient),
        display_id: resolvePublicIdentifier(admission.patient),
        human_friendly_id: resolvePublicIdentifier(admission.patient),
        first_name: admission.patient.first_name || null,
        last_name: admission.patient.last_name || null,
      }
    : null;

  return {
    id: resolvePublicIdentifier(admission),
    display_id: resolvePublicIdentifier(admission),
    human_friendly_id: resolvePublicIdentifier(admission),
    patient_display_id: resolvePublicIdentifier(admission.patient),
    patient_display_name: resolvePatientDisplayName(admission.patient),
    patient,
  };
};

const mapIcuStayRecord = (record) => {
  if (!record) return record;
  return {
    id: resolvePublicIdentifier(record),
    display_id: resolvePublicIdentifier(record),
    human_friendly_id: resolvePublicIdentifier(record),
    admission_id: resolvePublicIdentifier(record.admission),
    admission_display_id: resolvePublicIdentifier(record.admission),
    patient_display_id: resolvePublicIdentifier(record.admission?.patient),
    patient_display_name: resolvePatientDisplayName(record.admission?.patient),
    started_at: record.started_at || null,
    ended_at: record.ended_at || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    admission: mapAdmissionRelation(record.admission),
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

const resolveAdmission = async (identifier) =>
  resolveModelIdByIdentifier({
    model: 'admission',
    identifier,
    select: { id: true, tenant_id: true },
  });

const resolveIcuStay = async (identifier) =>
  resolveModelIdByIdentifier({
    model: 'icu_stay',
    identifier,
    select: { id: true },
  });

const resolveAuditTenantId = (record, fallback = null) =>
  record?.admission?.tenant_id || fallback || null;

const listIcuStays = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    if (filters.admission_id) {
      const resolvedAdmission = await resolveAdmission(filters.admission_id);
      if (!resolvedAdmission?.id) {
        return {
          icu_stays: [],
          pagination: buildEmptyPagination(page, limit),
        };
      }
      whereClause.admission_id = resolvedAdmission.id;
    }

    if (filters.started_at_from || filters.started_at_to) {
      whereClause.started_at = {};
      if (filters.started_at_from) {
        whereClause.started_at.gte = new Date(filters.started_at_from);
      }
      if (filters.started_at_to) {
        whereClause.started_at.lte = new Date(filters.started_at_to);
      }
    }

    if (filters.ended_at_from || filters.ended_at_to) {
      whereClause.ended_at = {};
      if (filters.ended_at_from) {
        whereClause.ended_at.gte = new Date(filters.ended_at_from);
      }
      if (filters.ended_at_to) {
        whereClause.ended_at.lte = new Date(filters.ended_at_to);
      }
    }

    if (filters.is_active !== undefined) {
      whereClause.ended_at = filters.is_active ? null : { not: null };
    }

    const [icuStays, total] = await Promise.all([
      icuStayRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        ICU_STAY_INCLUDE
      ),
      icuStayRepository.count(whereClause),
    ]);

    return {
      icu_stays: icuStays.map(mapIcuStayRecord),
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

const getIcuStayById = async (id) => {
  try {
    const resolvedIcuStay = await resolveIcuStay(id);
    if (!resolvedIcuStay?.id) {
      throw new HttpError('errors.icu_stay.not_found', 404);
    }

    const icuStay = await icuStayRepository.findById(
      resolvedIcuStay.id,
      ICU_STAY_INCLUDE
    );
    if (!icuStay) {
      throw new HttpError('errors.icu_stay.not_found', 404);
    }

    return mapIcuStayRecord(icuStay);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const createIcuStay = async (data, userId, ipAddress) => {
  try {
    const resolvedAdmission = await resolveAdmission(data?.admission_id);
    if (!resolvedAdmission?.id) {
      throw new HttpError('errors.admission.not_found', 404, [
        { field: 'admission_id' },
      ]);
    }

    const createdIcuStay = await icuStayRepository.create({
      ...data,
      admission_id: resolvedAdmission.id,
    });
    const icuStay =
      (await icuStayRepository.findById(createdIcuStay.id, ICU_STAY_INCLUDE)) ||
      createdIcuStay;

    createAuditLog({
      tenant_id: resolveAuditTenantId(icuStay, resolvedAdmission.tenant_id),
      user_id: userId,
      action: 'CREATE',
      entity: 'icu_stay',
      entity_id: icuStay.id,
      diff: { after: icuStay },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapIcuStayRecord(icuStay);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const updateIcuStay = async (id, data, userId, ipAddress) => {
  try {
    const resolvedIcuStay = await resolveIcuStay(id);
    if (!resolvedIcuStay?.id) {
      throw new HttpError('errors.icu_stay.not_found', 404);
    }

    const before = await icuStayRepository.findById(
      resolvedIcuStay.id,
      ICU_STAY_INCLUDE
    );
    if (!before) {
      throw new HttpError('errors.icu_stay.not_found', 404);
    }

    const updatedIcuStay = await icuStayRepository.update(resolvedIcuStay.id, data);
    const icuStay =
      (await icuStayRepository.findById(updatedIcuStay.id, ICU_STAY_INCLUDE)) ||
      updatedIcuStay;

    createAuditLog({
      tenant_id: resolveAuditTenantId(icuStay, resolveAuditTenantId(before)),
      user_id: userId,
      action: 'UPDATE',
      entity: 'icu_stay',
      entity_id: icuStay.id,
      diff: { before, after: icuStay },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapIcuStayRecord(icuStay);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const deleteIcuStay = async (id, userId, ipAddress) => {
  try {
    const resolvedIcuStay = await resolveIcuStay(id);
    if (!resolvedIcuStay?.id) {
      throw new HttpError('errors.icu_stay.not_found', 404);
    }

    const before = await icuStayRepository.findById(
      resolvedIcuStay.id,
      ICU_STAY_INCLUDE
    );
    if (!before) {
      throw new HttpError('errors.icu_stay.not_found', 404);
    }

    await icuStayRepository.softDelete(resolvedIcuStay.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'icu_stay',
      entity_id: resolvedIcuStay.id,
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
  listIcuStays,
  getIcuStayById,
  createIcuStay,
  updateIcuStay,
  deleteIcuStay,
};
