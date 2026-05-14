/**
 * Theatre case service
 *
 * @module modules/theatre-case/services
 * @description Business logic layer for theatre case operations.
 */

const theatreCaseRepository = require('@repositories/theatre-case/theatre-case.repository');
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

const resolveAuditTenantId = (record) =>
  sanitize(record?.encounter?.tenant_id) || null;

const buildEmptyListResult = (page, limit) => ({
  theatre_cases: [],
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

const resolveTheatreCaseRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'theatre_case',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  return theatreCaseRepository.findById(resolved.id);
};

const resolveTheatreCasePayloadIdentifiers = async (data = {}) => {
  const payload = { ...data };

  if (payload.encounter_id !== undefined) {
    payload.encounter_id = await resolvePayloadIdentifier({
      value: payload.encounter_id,
      field: 'encounter_id',
      model: 'encounter',
    });
  }

  if (payload.room_id !== undefined) {
    payload.room_id = await resolvePayloadIdentifier({
      value: payload.room_id,
      field: 'room_id',
      model: 'room',
      nullable: true,
    });
  }

  if (payload.surgeon_user_id !== undefined) {
    payload.surgeon_user_id = await resolvePayloadIdentifier({
      value: payload.surgeon_user_id,
      field: 'surgeon_user_id',
      model: 'user',
      nullable: true,
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

  return payload;
};

const createDisplayResolver = () => {
  const cache = new Map();

  return async (model, identifier, where = {}) => {
    const normalized = sanitize(identifier);
    if (!normalized) return null;

    const key = `${model}:${normalized}`;
    if (cache.has(key)) return cache.get(key);

    const record = await resolveModelRecordByIdentifier({
      model,
      identifier: normalized,
      where,
      select: {
        id: true,
        human_friendly_id: true,
      },
    });

    const value =
      resolveDisplayIdentifier(record) || (isUuidLike(normalized) ? null : normalized);
    cache.set(key, value);
    return value;
  };
};

const mapTheatreCaseForDisplay = async (record, resolveDisplayId) => {
  const encounter = record?.encounter || null;
  const patient = encounter?.patient || null;

  const mapped = {
    ...record,
    display_id: resolveDisplayIdentifier(record),
    encounter_display_id: resolveDisplayIdentifier(encounter),
    patient_display_id: resolveDisplayIdentifier(patient),
    patient_display_name: resolvePatientDisplayName(patient),
    room_display_id: null,
    surgeon_user_display_id: null,
    anesthetist_user_display_id: null,
  };

  const encounterScope = {
    tenant_id: encounter?.tenant_id || undefined,
  };

  if (record?.room_id) {
    mapped.room_display_id = await resolveDisplayId('room', record.room_id, encounterScope);
  }

  if (record?.surgeon_user_id) {
    mapped.surgeon_user_display_id = await resolveDisplayId(
      'user',
      record.surgeon_user_id,
      encounterScope
    );
  }

  if (record?.anesthetist_user_id) {
    mapped.anesthetist_user_display_id = await resolveDisplayId(
      'user',
      record.anesthetist_user_id,
      encounterScope
    );
  }

  return mapped;
};

const listTheatreCases = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { scheduled_at: 'desc' };
    const whereClause = {};

    const encounterId = await resolveFilterIdentifier({
      value: filters.encounter_id,
      model: 'encounter',
    });
    if (filters.encounter_id !== undefined && encounterId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (encounterId !== undefined) whereClause.encounter_id = encounterId;

    const patientId = await resolveFilterIdentifier({
      value: filters.patient_id,
      model: 'patient',
    });
    if (filters.patient_id !== undefined && patientId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (patientId) {
      whereClause.encounter = {
        ...(whereClause.encounter || {}),
        patient_id: patientId,
      };
    }

    const roomId = await resolveFilterIdentifier({
      value: filters.room_id,
      model: 'room',
    });
    if (filters.room_id !== undefined && roomId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (roomId !== undefined) whereClause.room_id = roomId;

    const surgeonUserId = await resolveFilterIdentifier({
      value: filters.surgeon_user_id,
      model: 'user',
    });
    if (filters.surgeon_user_id !== undefined && surgeonUserId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (surgeonUserId !== undefined) whereClause.surgeon_user_id = surgeonUserId;

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

    if (filters.status) whereClause.status = filters.status;

    if (filters.scheduled_from || filters.scheduled_to) {
      whereClause.scheduled_at = {};
      if (filters.scheduled_from) {
        whereClause.scheduled_at.gte = new Date(filters.scheduled_from);
      }
      if (filters.scheduled_to) {
        whereClause.scheduled_at.lte = new Date(filters.scheduled_to);
      }
    }

    if (filters.search) {
      const searchTerm = sanitize(filters.search);
      const upperSearchTerm = searchTerm.toUpperCase();
      whereClause.OR = [
        { human_friendly_id: { contains: upperSearchTerm } },
        { workflow_stage: { contains: searchTerm } },
        { stage_notes: { contains: searchTerm } },
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
      ];
    }

    const [theatreCases, total] = await Promise.all([
      theatreCaseRepository.findMany(whereClause, skip, limit, orderBy),
      theatreCaseRepository.count(whereClause),
    ]);

    const resolveDisplayId = createDisplayResolver();
    const mappedCases = await Promise.all(
      theatreCases.map((item) => mapTheatreCaseForDisplay(item, resolveDisplayId))
    );

    return {
      theatre_cases: mappedCases,
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

const getTheatreCaseById = async (id) => {
  try {
    const theatreCase = await resolveTheatreCaseRecordByIdentifier(id);

    if (!theatreCase) {
      throw new HttpError('errors.theatre_case.not_found', 404);
    }

    const resolveDisplayId = createDisplayResolver();
    return mapTheatreCaseForDisplay(theatreCase, resolveDisplayId);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const createTheatreCase = async (data, userId, ipAddress) => {
  try {
    const payload = await resolveTheatreCasePayloadIdentifiers(data);
    if (!payload.status) payload.status = 'SCHEDULED';

    const theatreCase = await theatreCaseRepository.create(payload);
    const createdRecord = await theatreCaseRepository.findById(theatreCase.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(createdRecord || theatreCase),
      user_id: userId,
      action: 'CREATE',
      entity: 'theatre_case',
      entity_id: theatreCase.id,
      diff: { after: createdRecord || theatreCase },
      ip_address: ipAddress,
    }).catch(() => {});

    const resolveDisplayId = createDisplayResolver();
    return mapTheatreCaseForDisplay(createdRecord || theatreCase, resolveDisplayId);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const updateTheatreCase = async (id, data, userId, ipAddress) => {
  try {
    const existingTheatreCase = await resolveTheatreCaseRecordByIdentifier(id);
    if (!existingTheatreCase) {
      throw new HttpError('errors.theatre_case.not_found', 404);
    }

    const payload = await resolveTheatreCasePayloadIdentifiers(data);
    const updatedTheatreCase = await theatreCaseRepository.update(
      existingTheatreCase.id,
      payload
    );
    const updatedRecord =
      (await theatreCaseRepository.findById(updatedTheatreCase.id)) || updatedTheatreCase;

    createAuditLog({
      tenant_id: resolveAuditTenantId(updatedRecord),
      user_id: userId,
      action: 'UPDATE',
      entity: 'theatre_case',
      entity_id: existingTheatreCase.id,
      diff: {
        before: existingTheatreCase,
        after: updatedRecord,
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const resolveDisplayId = createDisplayResolver();
    return mapTheatreCaseForDisplay(updatedRecord, resolveDisplayId);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const deleteTheatreCase = async (id, userId, ipAddress) => {
  try {
    const existingTheatreCase = await resolveTheatreCaseRecordByIdentifier(id);
    if (!existingTheatreCase) {
      throw new HttpError('errors.theatre_case.not_found', 404);
    }

    await theatreCaseRepository.softDelete(existingTheatreCase.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(existingTheatreCase),
      user_id: userId,
      action: 'DELETE',
      entity: 'theatre_case',
      entity_id: existingTheatreCase.id,
      diff: { before: existingTheatreCase },
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
  listTheatreCases,
  getTheatreCaseById,
  createTheatreCase,
  updateTheatreCase,
  deleteTheatreCase,
};
