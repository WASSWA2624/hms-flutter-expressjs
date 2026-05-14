/**
 * Appointment participant service
 *
 * @module modules/appointment-participant/services
 * @description Business logic layer for appointment participant operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const appointmentParticipantRepository = require('@repositories/appointment-participant/appointment-participant.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const USER_IDENTIFIER_MATCHERS = [({ rawValue }) => ({ email: rawValue }), ({ rawValue }) => ({ phone: rawValue })];
const ALLOWED_PARTICIPANT_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'role',
]);

const resolveSortBy = (value, fallback = 'created_at') => {
  const normalized = String(value || '').trim();
  return ALLOWED_PARTICIPANT_SORT_FIELDS.has(normalized) ? normalized : fallback;
};

const resolveSortOrder = (value, fallback = 'desc') => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'asc' || normalized === 'desc') return normalized;
  return fallback;
};

const APPOINTMENT_PARTICIPANT_INCLUDE = {
  appointment: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      facility: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      patient: {
        select: {
          id: true,
          human_friendly_id: true,
          first_name: true,
          last_name: true,
        },
      },
      provider: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          phone: true,
          profile: {
            select: {
              first_name: true,
              middle_name: true,
              last_name: true,
            },
          },
        },
      },
    },
  },
  participant_user: {
    select: {
      id: true,
      human_friendly_id: true,
      email: true,
      phone: true,
      profile: {
        select: {
          first_name: true,
          middle_name: true,
          last_name: true,
        },
      },
    },
  },
  participant_patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
    },
  },
};

const resolveDisplayName = (firstName, middleName, lastName) =>
  [firstName, middleName, lastName]
    .map((value) => (typeof value === 'string' ? value.trim() : ''))
    .filter(Boolean)
    .join(' ');

const appendIfPresent = (target, key, value) => {
  if (value === undefined || value === null || value === '') return;
  target[key] = value;
};

const withAppointmentParticipantProjection = (participant) => {
  if (!participant || typeof participant !== 'object') return participant;

  const projected = { ...participant };
  appendIfPresent(projected, 'appointment_human_friendly_id', participant?.appointment?.human_friendly_id);
  appendIfPresent(projected, 'tenant_human_friendly_id', participant?.appointment?.tenant?.human_friendly_id);
  appendIfPresent(projected, 'tenant_name', participant?.appointment?.tenant?.name);
  appendIfPresent(projected, 'facility_human_friendly_id', participant?.appointment?.facility?.human_friendly_id);
  appendIfPresent(projected, 'facility_name', participant?.appointment?.facility?.name);
  appendIfPresent(projected, 'patient_human_friendly_id', participant?.appointment?.patient?.human_friendly_id);
  appendIfPresent(projected, 'provider_human_friendly_id', participant?.appointment?.provider?.human_friendly_id);
  appendIfPresent(projected, 'participant_user_human_friendly_id', participant?.participant_user?.human_friendly_id);
  appendIfPresent(
    projected,
    'participant_user_display_name',
    resolveDisplayName(
      participant?.participant_user?.profile?.first_name,
      participant?.participant_user?.profile?.middle_name,
      participant?.participant_user?.profile?.last_name
    )
  );
  appendIfPresent(projected, 'participant_user_email', participant?.participant_user?.email);
  appendIfPresent(projected, 'participant_user_phone', participant?.participant_user?.phone);
  appendIfPresent(
    projected,
    'participant_patient_human_friendly_id',
    participant?.participant_patient?.human_friendly_id
  );
  appendIfPresent(
    projected,
    'participant_patient_display_name',
    resolveDisplayName(
      participant?.participant_patient?.first_name,
      null,
      participant?.participant_patient?.last_name
    )
  );
  return projected;
};

const withAppointmentParticipantProjectionList = (participants = []) =>
  (Array.isArray(participants) ? participants : []).map((participant) =>
    withAppointmentParticipantProjection(participant)
  );

const buildEmptyListResult = (page, limit) => ({
  participants: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveFilterIdentifier = async ({
  value,
  model,
  where = {},
  additionalFriendlyMatchers = [],
}) => {
  if (value === undefined) return undefined;
  if (value === null) return null;

  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) return undefined;

  const matchers = (additionalFriendlyMatchers || []).map((matcher) => (rawValue, upperValue) =>
    matcher({ rawValue, upperValue })
  );
  const resolvedId = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
    additionalFriendlyMatchers: matchers,
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
  additionalFriendlyMatchers = [],
}) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }

  const matchers = (additionalFriendlyMatchers || []).map((matcher) => (rawValue, upperValue) =>
    matcher({ rawValue, upperValue })
  );
  const resolvedId = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
    additionalFriendlyMatchers: matchers,
  });

  if (resolvedId) return resolvedId;
  if (isUuidLike(normalized)) return normalized;

  throw new HttpError('errors.validation.invalid', 400, [{ field }]);
};

const resolveParticipantPayloadIdentifiers = async (data = {}, existing = null) => {
  const payload = { ...data };

  const appointmentIdentifier =
    payload.appointment_id !== undefined ? payload.appointment_id : existing?.appointment_id;
  const appointmentRecord = appointmentIdentifier
    ? await resolveModelRecordByIdentifier({
        model: 'appointment',
        identifier: appointmentIdentifier,
        select: { id: true, tenant_id: true },
      })
    : null;

  if (payload.appointment_id !== undefined) {
    payload.appointment_id = await resolvePayloadIdentifier({
      value: payload.appointment_id,
      field: 'appointment_id',
      model: 'appointment',
    });
  }

  const tenantId = appointmentRecord?.tenant_id || null;

  if (payload.participant_user_id !== undefined) {
    payload.participant_user_id = await resolvePayloadIdentifier({
      value: payload.participant_user_id,
      field: 'participant_user_id',
      model: 'user',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
      additionalFriendlyMatchers: USER_IDENTIFIER_MATCHERS,
    });
  }

  if (payload.participant_patient_id !== undefined) {
    payload.participant_patient_id = await resolvePayloadIdentifier({
      value: payload.participant_patient_id,
      field: 'participant_patient_id',
      model: 'patient',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
  }

  return payload;
};

const resolveParticipantRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'appointment_participant',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  const participant = await appointmentParticipantRepository.findById(
    resolved.id,
    APPOINTMENT_PARTICIPANT_INCLUDE
  );
  return withAppointmentParticipantProjection(participant);
};

/**
 * List appointment participants with pagination and filtering
 */
const listAppointmentParticipants = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const resolvedSortBy = resolveSortBy(sortBy, 'created_at');
    const resolvedOrder = resolveSortOrder(order, 'desc');
    const orderBy = { [resolvedSortBy]: resolvedOrder };

    const whereClause = {};
    
    const appointmentId = await resolveFilterIdentifier({
      value: filters.appointment_id,
      model: 'appointment',
    });
    if (filters.appointment_id !== undefined && appointmentId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (appointmentId) whereClause.appointment_id = appointmentId;

    const appointmentRecord = appointmentId
      ? await resolveModelRecordByIdentifier({
          model: 'appointment',
          identifier: appointmentId,
          select: { id: true, tenant_id: true },
        })
      : null;
    const tenantId = appointmentRecord?.tenant_id || null;

    const participantUserId = await resolveFilterIdentifier({
      value: filters.participant_user_id,
      model: 'user',
      where: tenantId ? { tenant_id: tenantId } : {},
      additionalFriendlyMatchers: USER_IDENTIFIER_MATCHERS,
    });
    if (filters.participant_user_id !== undefined && participantUserId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (participantUserId !== undefined) whereClause.participant_user_id = participantUserId;

    const participantPatientId = await resolveFilterIdentifier({
      value: filters.participant_patient_id,
      model: 'patient',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
    if (filters.participant_patient_id !== undefined && participantPatientId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (participantPatientId !== undefined) whereClause.participant_patient_id = participantPatientId;

    if (filters.role) whereClause.role = { contains: filters.role };

    const [participants, total] = await Promise.all([
      appointmentParticipantRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        APPOINTMENT_PARTICIPANT_INCLUDE
      ),
      appointmentParticipantRepository.count(whereClause)
    ]);

    return {
      participants: withAppointmentParticipantProjectionList(participants),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get appointment participant by ID
 */
const getAppointmentParticipantById = async (id, userId, ipAddress) => {
  try {
    const participant = await resolveParticipantRecordByIdentifier(id);

    if (!participant) {
      throw new HttpError('errors.appointment_participant.not_found', 404);
    }

    return participant;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new appointment participant
 */
const createAppointmentParticipant = async (data, userId, ipAddress) => {
  try {
    const payload = await resolveParticipantPayloadIdentifiers(data);
    const createdParticipant = await appointmentParticipantRepository.create(payload);
    const participant = await appointmentParticipantRepository.findById(
      createdParticipant.id,
      APPOINTMENT_PARTICIPANT_INCLUDE
    );
    const projectedParticipant = withAppointmentParticipantProjection(participant || createdParticipant);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'appointment_participant',
      entity_id: createdParticipant.id,
      diff: { after: projectedParticipant },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedParticipant;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update appointment participant
 */
const updateAppointmentParticipant = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveParticipantRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment_participant.not_found', 404);
    }

    const payload = await resolveParticipantPayloadIdentifiers(data, before);
    const updatedParticipant = await appointmentParticipantRepository.update(before.id, payload);
    const participant = await appointmentParticipantRepository.findById(
      updatedParticipant.id,
      APPOINTMENT_PARTICIPANT_INCLUDE
    );
    const projectedParticipant = withAppointmentParticipantProjection(participant || updatedParticipant);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'appointment_participant',
      entity_id: updatedParticipant.id,
      diff: { before, after: projectedParticipant },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedParticipant;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete appointment participant (soft delete)
 */
const deleteAppointmentParticipant = async (id, userId, ipAddress) => {
  try {
    const before = await resolveParticipantRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment_participant.not_found', 404);
    }

    await appointmentParticipantRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'appointment_participant',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listAppointmentParticipants,
  getAppointmentParticipantById,
  createAppointmentParticipant,
  updateAppointmentParticipant,
  deleteAppointmentParticipant
};
