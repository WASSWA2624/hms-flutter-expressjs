/**
 * Appointment reminder service
 *
 * @module modules/appointment-reminder/services
 * @description Business logic layer for appointment reminder operations.
 */

const appointmentReminderRepository = require('@repositories/appointment-reminder/appointment-reminder.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const DUE_WINDOW_MS = 24 * 60 * 60 * 1000;
const ALLOWED_REMINDER_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'scheduled_at',
  'sent_at',
  'channel',
]);

const resolveSortBy = (value, fallback = 'created_at') => {
  const normalized = String(value || '').trim();
  return ALLOWED_REMINDER_SORT_FIELDS.has(normalized) ? normalized : fallback;
};

const resolveSortOrder = (value, fallback = 'desc') => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'asc' || normalized === 'desc') return normalized;
  return fallback;
};

const APPOINTMENT_REMINDER_INCLUDE = {
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

const withAppointmentReminderProjection = (reminder) => {
  if (!reminder || typeof reminder !== 'object') return reminder;

  const projected = { ...reminder };
  appendIfPresent(projected, 'appointment_human_friendly_id', reminder?.appointment?.human_friendly_id);
  appendIfPresent(projected, 'tenant_human_friendly_id', reminder?.appointment?.tenant?.human_friendly_id);
  appendIfPresent(projected, 'tenant_name', reminder?.appointment?.tenant?.name);
  appendIfPresent(projected, 'facility_human_friendly_id', reminder?.appointment?.facility?.human_friendly_id);
  appendIfPresent(projected, 'facility_name', reminder?.appointment?.facility?.name);
  appendIfPresent(projected, 'patient_human_friendly_id', reminder?.appointment?.patient?.human_friendly_id);
  appendIfPresent(
    projected,
    'patient_display_name',
    resolveDisplayName(
      reminder?.appointment?.patient?.first_name,
      null,
      reminder?.appointment?.patient?.last_name
    )
  );
  appendIfPresent(projected, 'provider_human_friendly_id', reminder?.appointment?.provider?.human_friendly_id);
  appendIfPresent(
    projected,
    'provider_display_name',
    resolveDisplayName(
      reminder?.appointment?.provider?.profile?.first_name,
      reminder?.appointment?.provider?.profile?.middle_name,
      reminder?.appointment?.provider?.profile?.last_name
    )
  );
  appendIfPresent(projected, 'provider_email', reminder?.appointment?.provider?.email);
  appendIfPresent(projected, 'provider_phone', reminder?.appointment?.provider?.phone);
  return projected;
};

const withAppointmentReminderProjectionList = (reminders = []) =>
  (Array.isArray(reminders) ? reminders : []).map((reminder) =>
    withAppointmentReminderProjection(reminder)
  );

const buildEmptyListResult = (page, limit) => ({
  reminders: [],
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

  const normalized = typeof value === 'string' ? value.trim() : '';
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

const resolvePayloadIdentifier = async ({ value, field, model, where = {} }) => {
  if (value === undefined) return undefined;
  if (value === null) {
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
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

const resolveReminderPayloadIdentifiers = async (data = {}) => {
  const payload = { ...data };

  if (payload.appointment_id !== undefined) {
    payload.appointment_id = await resolvePayloadIdentifier({
      value: payload.appointment_id,
      field: 'appointment_id',
      model: 'appointment',
    });
  }

  return payload;
};

const resolveReminderRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'appointment_reminder',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  const reminder = await appointmentReminderRepository.findById(resolved.id, APPOINTMENT_REMINDER_INCLUDE);
  return withAppointmentReminderProjection(reminder);
};

const listAppointmentReminders = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
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

    if (filters.channel) whereClause.channel = filters.channel;

    const andClauses = [];
    if (filters.is_sent !== undefined) {
      andClauses.push(filters.is_sent ? { sent_at: { not: null } } : { sent_at: null });
    }

    if (filters.due_state) {
      const now = new Date();
      if (filters.due_state === 'OVERDUE') {
        andClauses.push({ sent_at: null });
        andClauses.push({ scheduled_at: { lt: now } });
      }

      if (filters.due_state === 'DUE') {
        andClauses.push({ sent_at: null });
        andClauses.push({
          scheduled_at: {
            gte: now,
            lt: new Date(now.getTime() + DUE_WINDOW_MS),
          },
        });
      }
    }

    if (andClauses.length > 0) {
      whereClause.AND = andClauses;
    }

    const [reminders, total] = await Promise.all([
      appointmentReminderRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        APPOINTMENT_REMINDER_INCLUDE
      ),
      appointmentReminderRepository.count(whereClause)
    ]);

    return {
      reminders: withAppointmentReminderProjectionList(reminders),
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

const getAppointmentReminderById = async (id, userId, ipAddress) => {
  try {
    const reminder = await resolveReminderRecordByIdentifier(id);

    if (!reminder) {
      throw new HttpError('errors.appointment_reminder.not_found', 404);
    }

    return reminder;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createAppointmentReminder = async (data, userId, ipAddress) => {
  try {
    const payload = await resolveReminderPayloadIdentifiers(data);
    const createdReminder = await appointmentReminderRepository.create(payload);
    const reminder = await appointmentReminderRepository.findById(
      createdReminder.id,
      APPOINTMENT_REMINDER_INCLUDE
    );
    const projectedReminder = withAppointmentReminderProjection(reminder || createdReminder);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'appointment_reminder',
      entity_id: createdReminder.id,
      diff: { after: projectedReminder },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedReminder;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateAppointmentReminder = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveReminderRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment_reminder.not_found', 404);
    }

    const payload = await resolveReminderPayloadIdentifiers(data);
    const updatedReminder = await appointmentReminderRepository.update(before.id, payload);
    const reminder = await appointmentReminderRepository.findById(
      updatedReminder.id,
      APPOINTMENT_REMINDER_INCLUDE
    );
    const projectedReminder = withAppointmentReminderProjection(reminder || updatedReminder);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'appointment_reminder',
      entity_id: updatedReminder.id,
      diff: { before, after: projectedReminder },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedReminder;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteAppointmentReminder = async (id, userId, ipAddress) => {
  try {
    const before = await resolveReminderRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment_reminder.not_found', 404);
    }

    await appointmentReminderRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'appointment_reminder',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const markAppointmentReminderSent = async (id, payload = {}, userId, ipAddress) => {
  try {
    const before = await resolveReminderRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment_reminder.not_found', 404);
    }

    if (before.sent_at) {
      return before;
    }

    const sentAt = payload?.sent_at ? new Date(payload.sent_at) : new Date();
    const updatedReminder = await appointmentReminderRepository.update(before.id, { sent_at: sentAt });
    const reminder = await appointmentReminderRepository.findById(
      updatedReminder.id,
      APPOINTMENT_REMINDER_INCLUDE
    );
    const projectedReminder = withAppointmentReminderProjection(reminder || updatedReminder);

    createAuditLog({
      user_id: userId,
      action: 'MARK_SENT',
      entity: 'appointment_reminder',
      entity_id: updatedReminder.id,
      diff: { before, after: projectedReminder },
      ip_address: ipAddress,
    }).catch(() => {});

    return projectedReminder;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listAppointmentReminders,
  getAppointmentReminderById,
  createAppointmentReminder,
  updateAppointmentReminder,
  deleteAppointmentReminder,
  markAppointmentReminderSent,
};
