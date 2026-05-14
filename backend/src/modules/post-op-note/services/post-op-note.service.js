/**
 * Post-op note service
 *
 * @module modules/post-op-note/services
 * @description Business logic layer for post-op note operations.
 */

const postOpNoteRepository = require('@repositories/post-op-note/post-op-note.repository');
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
  sanitize(record?.theatre_case?.encounter?.tenant_id) || null;

const buildEmptyListResult = (page, limit) => ({
  post_op_notes: [],
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

const resolvePostOpNoteByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'post_op_note',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  return postOpNoteRepository.findById(resolved.id);
};

const resolvePostOpPayloadIdentifiers = async (data = {}) => {
  const payload = { ...data };

  if (payload.theatre_case_id !== undefined) {
    payload.theatre_case_id = await resolvePayloadIdentifier({
      value: payload.theatre_case_id,
      field: 'theatre_case_id',
      model: 'theatre_case',
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

const mapPostOpNoteForDisplay = (record) => {
  const theatreCase = record?.theatre_case || null;
  const encounter = theatreCase?.encounter || null;
  const patient = encounter?.patient || null;

  return {
    ...record,
    display_id: resolveDisplayIdentifier(record),
    theatre_case_display_id: resolveDisplayIdentifier(theatreCase),
    encounter_display_id: resolveDisplayIdentifier(encounter),
    patient_display_id: resolveDisplayIdentifier(patient),
    patient_display_name: resolvePatientDisplayName(patient),
  };
};

const listpostOpNotes = async (filters, page, limit, sortBy, order) => {
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
        { note: { contains: searchTerm } },
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

    const [postOpNotes, total] = await Promise.all([
      postOpNoteRepository.findMany(whereClause, skip, limit, orderBy),
      postOpNoteRepository.count(whereClause),
    ]);

    return {
      post_op_notes: postOpNotes.map(mapPostOpNoteForDisplay),
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

const getpostOpNoteById = async (id) => {
  try {
    const postOpNote = await resolvePostOpNoteByIdentifier(id);

    if (!postOpNote) {
      throw new HttpError('errors.post_op_note.not_found', 404);
    }

    return mapPostOpNoteForDisplay(postOpNote);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const createpostOpNote = async (data, userId, ipAddress) => {
  try {
    const payload = await resolvePostOpPayloadIdentifiers(data);
    if (!payload.record_status) payload.record_status = 'DRAFT';

    const postOpNote = await postOpNoteRepository.create(payload);
    const createdRecord =
      (await postOpNoteRepository.findById(postOpNote.id)) || postOpNote;

    createAuditLog({
      tenant_id: resolveAuditTenantId(createdRecord),
      user_id: userId,
      action: 'CREATE',
      entity: 'post_op_note',
      entity_id: postOpNote.id,
      diff: { after: createdRecord },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapPostOpNoteForDisplay(createdRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const updatepostOpNote = async (id, data, userId, ipAddress) => {
  try {
    const existingpostOpNote = await resolvePostOpNoteByIdentifier(id);
    if (!existingpostOpNote) {
      throw new HttpError('errors.post_op_note.not_found', 404);
    }

    const payload = await resolvePostOpPayloadIdentifiers(data);
    const updatedpostOpNote = await postOpNoteRepository.update(
      existingpostOpNote.id,
      payload
    );
    const updatedRecord =
      (await postOpNoteRepository.findById(updatedpostOpNote.id)) || updatedpostOpNote;

    createAuditLog({
      tenant_id: resolveAuditTenantId(updatedRecord),
      user_id: userId,
      action: 'UPDATE',
      entity: 'post_op_note',
      entity_id: existingpostOpNote.id,
      diff: {
        before: existingpostOpNote,
        after: updatedRecord,
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapPostOpNoteForDisplay(updatedRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const deletepostOpNote = async (id, userId, ipAddress) => {
  try {
    const existingpostOpNote = await resolvePostOpNoteByIdentifier(id);
    if (!existingpostOpNote) {
      throw new HttpError('errors.post_op_note.not_found', 404);
    }

    await postOpNoteRepository.softDelete(existingpostOpNote.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(existingpostOpNote),
      user_id: userId,
      action: 'DELETE',
      entity: 'post_op_note',
      entity_id: existingpostOpNote.id,
      diff: { before: existingpostOpNote },
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
  listpostOpNotes,
  getpostOpNoteById,
  createpostOpNote,
  updatepostOpNote,
  deletepostOpNote,
};
