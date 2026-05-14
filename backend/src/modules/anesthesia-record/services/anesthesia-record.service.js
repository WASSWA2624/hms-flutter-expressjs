/**
 * Anesthesia record service
 *
 * @module modules/anesthesia-record/services
 * @description Business logic layer for anesthesia record operations.
 */

const anesthesiaRecordRepository = require('@repositories/anesthesia-record/anesthesia-record.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const sanitize = (value) => String(value || '').trim();

const resolveDisplayIdentifier = (record) => {
  if (!record) return null;
  const friendly = sanitize(record.human_friendly_id || record.display_id);
  if (friendly && !isUuidLike(friendly)) return friendly;
  const scalar = sanitize(record.id);
  if (scalar && !isUuidLike(scalar)) return scalar;
  return null;
};

const resolvePatientDisplayName = (patient) => {
  const first = sanitize(patient?.first_name);
  const last = sanitize(patient?.last_name);
  const full = [first, last].filter(Boolean).join(' ').trim();
  return full || null;
};

const resolveUserDisplayName = (user) => {
  const profile = user?.profile || null;
  const full = [
    sanitize(profile?.first_name),
    sanitize(profile?.middle_name),
    sanitize(profile?.last_name),
  ]
    .filter(Boolean)
    .join(' ')
    .trim();
  return full || null;
};

const resolveAuditTenantId = (record) =>
  sanitize(record?.theatre_case?.encounter?.tenant_id) || null;

const buildEmptyListResult = (page, limit) => ({
  anesthesia_records: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveFilterIdentifier = async ({ value, model, where = {} }) => {
  if (value === undefined) return undefined;
  if (value === null) return null;

  const normalized = sanitize(value);
  if (!normalized) return undefined;

  const resolvedId = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
  });

  if (resolvedId) return resolvedId;
  if (isUuidLike(normalized)) return normalized;
  return null;
};

const resolvePayloadIdentifier = async ({
  value,
  field,
  model,
  where = {},
  nullable = false,
}) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const normalized = sanitize(value);
  if (!normalized) {
    if (nullable) return null;
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }

  const resolvedId = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
  });

  if (resolvedId) return resolvedId;
  if (isUuidLike(normalized)) return normalized;

  throw new HttpError('errors.validation.invalid', 400, [{ field }]);
};

const resolveAnesthesiaRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'anesthesia_record',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  return anesthesiaRecordRepository.findById(resolved.id);
};

const resolveAnesthesiaPayloadIdentifiers = async (data = {}) => {
  const payload = { ...data };

  if (payload.theatre_case_id !== undefined) {
    payload.theatre_case_id = await resolvePayloadIdentifier({
      value: payload.theatre_case_id,
      field: 'theatre_case_id',
      model: 'theatre_case',
    });
  }

  if (payload.anesthetist_user_id !== undefined) {
    payload.anesthetist_user_id = await resolvePayloadIdentifier({
      value: payload.anesthetist_user_id,
      field: 'anesthetist_user_id',
      model: 'user',
      nullable: true,
    });
  }

  if (payload.finalized_by_user_id !== undefined) {
    payload.finalized_by_user_id = await resolvePayloadIdentifier({
      value: payload.finalized_by_user_id,
      field: 'finalized_by_user_id',
      model: 'user',
      nullable: true,
    });
  }

  if (payload.reopened_by_user_id !== undefined) {
    payload.reopened_by_user_id = await resolvePayloadIdentifier({
      value: payload.reopened_by_user_id,
      field: 'reopened_by_user_id',
      model: 'user',
      nullable: true,
    });
  }

  return payload;
};

const mapAnesthesiaRecordForDisplay = (record) => {
  const theatreCase = record?.theatre_case || null;
  const encounter = theatreCase?.encounter || null;
  const patient = encounter?.patient || null;
  const anesthetist = record?.anesthetist || null;

  return {
    ...record,
    display_id: resolveDisplayIdentifier(record),
    theatre_case_display_id: resolveDisplayIdentifier(theatreCase),
    encounter_display_id: resolveDisplayIdentifier(encounter),
    patient_display_id: resolveDisplayIdentifier(patient),
    patient_display_name: resolvePatientDisplayName(patient),
    anesthetist_user_display_id: resolveDisplayIdentifier(anesthetist),
    staff_profile_display_id:
      resolveDisplayIdentifier(anesthetist?.staff_profile) || null,
    anesthetist_display_name: resolveUserDisplayName(anesthetist),
  };
};

const listAnesthesiaRecords = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const theatreCaseId = await resolveFilterIdentifier({
      value: filters.theatre_case_id,
      model: 'theatre_case',
    });
    if (filters.theatre_case_id !== undefined && theatreCaseId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (theatreCaseId !== undefined) whereClause.theatre_case_id = theatreCaseId;

    const anesthetistUserId = await resolveFilterIdentifier({
      value: filters.anesthetist_user_id,
      model: 'user',
    });
    if (filters.anesthetist_user_id !== undefined && anesthetistUserId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (anesthetistUserId !== undefined) {
      whereClause.anesthetist_user_id = anesthetistUserId;
    }

    const encounterId = await resolveFilterIdentifier({
      value: filters.encounter_id,
      model: 'encounter',
    });
    if (filters.encounter_id !== undefined && encounterId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (encounterId) {
      whereClause.theatre_case = {
        ...(whereClause.theatre_case || {}),
        encounter_id: encounterId,
      };
    }

    const patientId = await resolveFilterIdentifier({
      value: filters.patient_id,
      model: 'patient',
    });
    if (filters.patient_id !== undefined && patientId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (patientId) {
      whereClause.theatre_case = {
        ...(whereClause.theatre_case || {}),
        encounter: {
          ...(whereClause.theatre_case?.encounter || {}),
          patient_id: patientId,
        },
      };
    }

    if (filters.record_status) {
      whereClause.record_status = filters.record_status;
    }

    if (filters.search) {
      const searchTerm = sanitize(filters.search);
      const upperSearchTerm = searchTerm.toUpperCase();
      whereClause.OR = [
        { human_friendly_id: { contains: upperSearchTerm } },
        { notes: { contains: searchTerm } },
        {
          theatre_case: {
            OR: [
              { human_friendly_id: { contains: upperSearchTerm } },
              {
                encounter: {
                  OR: [
                    { human_friendly_id: { contains: upperSearchTerm } },
                    {
                      patient: {
                        OR: [
                          { human_friendly_id: { contains: upperSearchTerm } },
                          { first_name: { contains: searchTerm } },
                          { last_name: { contains: searchTerm } },
                        ],
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      ];
    }

    const [records, total] = await Promise.all([
      anesthesiaRecordRepository.findMany(whereClause, skip, limit, orderBy),
      anesthesiaRecordRepository.count(whereClause),
    ]);

    return {
      anesthesia_records: records.map(mapAnesthesiaRecordForDisplay),
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

const getAnesthesiaRecordById = async (id) => {
  try {
    const anesthesiaRecord = await resolveAnesthesiaRecordByIdentifier(id);

    if (!anesthesiaRecord) {
      throw new HttpError('errors.anesthesia_record.not_found', 404);
    }

    return mapAnesthesiaRecordForDisplay(anesthesiaRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const createAnesthesiaRecord = async (data, userId, ipAddress) => {
  try {
    const payload = await resolveAnesthesiaPayloadIdentifiers(data);
    if (!payload.record_status) payload.record_status = 'DRAFT';

    const anesthesiaRecord = await anesthesiaRecordRepository.create(payload);
    const createdRecord =
      (await anesthesiaRecordRepository.findById(anesthesiaRecord.id)) || anesthesiaRecord;

    createAuditLog({
      tenant_id: resolveAuditTenantId(createdRecord),
      user_id: userId,
      action: 'CREATE',
      entity: 'anesthesia_record',
      entity_id: anesthesiaRecord.id,
      diff: { after: createdRecord },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapAnesthesiaRecordForDisplay(createdRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const updateAnesthesiaRecord = async (id, data, userId, ipAddress) => {
  try {
    const existingAnesthesiaRecord = await resolveAnesthesiaRecordByIdentifier(id);
    if (!existingAnesthesiaRecord) {
      throw new HttpError('errors.anesthesia_record.not_found', 404);
    }

    const payload = await resolveAnesthesiaPayloadIdentifiers(data);
    const updatedAnesthesiaRecord = await anesthesiaRecordRepository.update(
      existingAnesthesiaRecord.id,
      payload
    );
    const updatedRecord =
      (await anesthesiaRecordRepository.findById(updatedAnesthesiaRecord.id)) ||
      updatedAnesthesiaRecord;

    createAuditLog({
      tenant_id: resolveAuditTenantId(updatedRecord),
      user_id: userId,
      action: 'UPDATE',
      entity: 'anesthesia_record',
      entity_id: existingAnesthesiaRecord.id,
      diff: {
        before: existingAnesthesiaRecord,
        after: updatedRecord,
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapAnesthesiaRecordForDisplay(updatedRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const deleteAnesthesiaRecord = async (id, userId, ipAddress) => {
  try {
    const existingAnesthesiaRecord = await resolveAnesthesiaRecordByIdentifier(id);
    if (!existingAnesthesiaRecord) {
      throw new HttpError('errors.anesthesia_record.not_found', 404);
    }

    await anesthesiaRecordRepository.softDelete(existingAnesthesiaRecord.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(existingAnesthesiaRecord),
      user_id: userId,
      action: 'DELETE',
      entity: 'anesthesia_record',
      entity_id: existingAnesthesiaRecord.id,
      diff: { before: existingAnesthesiaRecord },
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
  listAnesthesiaRecords,
  getAnesthesiaRecordById,
  createAnesthesiaRecord,
  updateAnesthesiaRecord,
  deleteAnesthesiaRecord,
};
