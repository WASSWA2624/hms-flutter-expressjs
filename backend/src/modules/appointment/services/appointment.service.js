/**
 * Appointment service
 *
 * @module modules/appointment/services
 * @description Business logic layer for appointment operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const appointmentRepository = require('@repositories/appointment/appointment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const USER_IDENTIFIER_MATCHERS = [({ rawValue }) => ({ email: rawValue }), ({ rawValue }) => ({ phone: rawValue })];
const ALLOWED_APPOINTMENT_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'scheduled_start',
  'scheduled_end',
  'status',
]);

const resolveSortBy = (value, fallback = 'created_at') => {
  const normalized = String(value || '').trim();
  return ALLOWED_APPOINTMENT_SORT_FIELDS.has(normalized) ? normalized : fallback;
};

const resolveSortOrder = (value, fallback = 'desc') => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'asc' || normalized === 'desc') return normalized;
  return fallback;
};

const APPOINTMENT_INCLUDE = {
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
      date_of_birth: true,
      gender: true,
      contacts: {
        where: { deleted_at: null },
        orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
        take: 3,
        select: {
          contact_type: true,
          value: true,
          is_primary: true,
        },
      },
      identifiers: {
        where: { deleted_at: null },
        orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
        take: 3,
        select: {
          identifier_type: true,
          identifier_value: true,
          is_primary: true,
        },
      },
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
};

const resolveDisplayName = (firstName, middleName, lastName) =>
  [firstName, middleName, lastName]
    .map((value) => (typeof value === 'string' ? value.trim() : ''))
    .filter(Boolean)
    .join(' ');

const resolvePrimaryRecord = (records = []) => {
  if (!Array.isArray(records)) return null;
  return records.find((record) => record?.is_primary) || records[0] || null;
};

const appendIfPresent = (target, key, value) => {
  if (value === undefined || value === null || value === '') return;
  target[key] = value;
};

const withAppointmentProjection = (appointment) => {
  if (!appointment || typeof appointment !== 'object') return appointment;

  const patientDisplayName = resolveDisplayName(
    appointment?.patient?.first_name,
    null,
    appointment?.patient?.last_name
  );
  const primaryContact = resolvePrimaryRecord(appointment?.patient?.contacts);
  const primaryIdentifier = resolvePrimaryRecord(appointment?.patient?.identifiers);
  const providerDisplayName = resolveDisplayName(
    appointment?.provider?.profile?.first_name,
    appointment?.provider?.profile?.middle_name,
    appointment?.provider?.profile?.last_name
  );

  const projected = { ...appointment };
  appendIfPresent(projected, 'tenant_human_friendly_id', appointment?.tenant?.human_friendly_id);
  appendIfPresent(projected, 'tenant_name', appointment?.tenant?.name);
  appendIfPresent(projected, 'facility_human_friendly_id', appointment?.facility?.human_friendly_id);
  appendIfPresent(projected, 'facility_name', appointment?.facility?.name);
  appendIfPresent(projected, 'patient_human_friendly_id', appointment?.patient?.human_friendly_id);
  appendIfPresent(projected, 'patient_display_name', patientDisplayName);
  appendIfPresent(projected, 'patient_first_name', appointment?.patient?.first_name);
  appendIfPresent(projected, 'patient_last_name', appointment?.patient?.last_name);
  appendIfPresent(projected, 'patient_date_of_birth', appointment?.patient?.date_of_birth);
  appendIfPresent(projected, 'patient_gender', appointment?.patient?.gender);
  appendIfPresent(projected, 'patient_primary_phone', primaryContact?.value);
  appendIfPresent(projected, 'patient_primary_contact_type', primaryContact?.contact_type);
  appendIfPresent(projected, 'patient_primary_identifier', primaryIdentifier?.identifier_value);
  appendIfPresent(projected, 'patient_primary_identifier_type', primaryIdentifier?.identifier_type);
  appendIfPresent(projected, 'provider_human_friendly_id', appointment?.provider?.human_friendly_id);
  appendIfPresent(projected, 'provider_display_name', providerDisplayName);
  appendIfPresent(projected, 'provider_email', appointment?.provider?.email);
  appendIfPresent(projected, 'provider_phone', appointment?.provider?.phone);
  return projected;
};

const withAppointmentProjectionList = (appointments = []) =>
  (Array.isArray(appointments) ? appointments : []).map((appointment) =>
    withAppointmentProjection(appointment)
  );

const buildEmptyListResult = (page, limit) => ({
  appointments: [],
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

const resolveAppointmentPayloadIdentifiers = async (data = {}, existing = null) => {
  const payload = { ...data };

  const tenantId =
    payload.tenant_id !== undefined
      ? await resolvePayloadIdentifier({
          value: payload.tenant_id,
          field: 'tenant_id',
          model: 'tenant',
        })
      : existing?.tenant_id;

  if (payload.tenant_id !== undefined) {
    payload.tenant_id = tenantId;
  }

  if (payload.facility_id !== undefined) {
    payload.facility_id = await resolvePayloadIdentifier({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
  }

  if (payload.patient_id !== undefined) {
    payload.patient_id = await resolvePayloadIdentifier({
      value: payload.patient_id,
      field: 'patient_id',
      model: 'patient',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (payload.provider_user_id !== undefined) {
    payload.provider_user_id = await resolvePayloadIdentifier({
      value: payload.provider_user_id,
      field: 'provider_user_id',
      model: 'user',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
      additionalFriendlyMatchers: USER_IDENTIFIER_MATCHERS,
    });
  }

  return payload;
};

const normalizeStatus = (value) => String(value || '').trim().toUpperCase();

const resolveAppointmentRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'appointment',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  const appointment = await appointmentRepository.findById(resolved.id, APPOINTMENT_INCLUDE);
  return withAppointmentProjection(appointment);
};

const shouldAutoStartOpdFlow = (before, appointment, updateData = {}) => {
  const nextStatus = normalizeStatus(appointment?.status || updateData?.status);
  if (nextStatus !== 'IN_PROGRESS') return false;

  const previousStatus = normalizeStatus(before?.status);
  return previousStatus !== 'IN_PROGRESS';
};

const maybeAutoStartOpdFlow = async ({ before, appointment, updateData, userId, ipAddress }) => {
  if (!appointment?.id) return;
  if (!shouldAutoStartOpdFlow(before, appointment, updateData)) return;

  try {
    await opdFlowService.startOpdFlow(
      {
        appointment_id: appointment.id,
        arrival_mode: 'ONLINE_APPOINTMENT',
        tenant_id: appointment.tenant_id || undefined,
        facility_id: appointment.facility_id || undefined,
        notes: 'Auto-started from appointment status transition to IN_PROGRESS.',
      },
      {
        user_id: userId,
        tenant_id: appointment.tenant_id || undefined,
        facility_id: appointment.facility_id || undefined,
        ip_address: ipAddress,
      }
    );
  } catch (_error) {
    // Keep appointment lifecycle updates non-blocking even if OPD orchestration fails.
  }
};

/**
 * List appointments with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Appointments and pagination data
 */
const listAppointments = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const resolvedSortBy = resolveSortBy(sortBy, 'created_at');
    const resolvedOrder = resolveSortOrder(order, 'desc');
    const orderBy = { [resolvedSortBy]: resolvedOrder };

    // Build filter object
    const whereClause = {};

    const tenantId = await resolveFilterIdentifier({
      value: filters.tenant_id,
      model: 'tenant',
    });
    if (filters.tenant_id !== undefined && tenantId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (tenantId) whereClause.tenant_id = tenantId;

    const facilityId = await resolveFilterIdentifier({
      value: filters.facility_id,
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
    if (filters.facility_id !== undefined && facilityId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (facilityId !== undefined) whereClause.facility_id = facilityId;

    const patientId = await resolveFilterIdentifier({
      value: filters.patient_id,
      model: 'patient',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
    if (filters.patient_id !== undefined && patientId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (patientId) whereClause.patient_id = patientId;

    const providerUserId = await resolveFilterIdentifier({
      value: filters.provider_user_id,
      model: 'user',
      where: tenantId ? { tenant_id: tenantId } : {},
      additionalFriendlyMatchers: USER_IDENTIFIER_MATCHERS,
    });
    if (filters.provider_user_id !== undefined && providerUserId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (providerUserId !== undefined) whereClause.provider_user_id = providerUserId;

    if (filters.status) whereClause.status = filters.status;

    if (filters.search) {
      const searchTerm = String(filters.search).trim();
      const upperSearchTerm = searchTerm.toUpperCase();
      whereClause.OR = [
        { reason: { contains: searchTerm } },
        { human_friendly_id: { contains: upperSearchTerm } },
        {
          patient: {
            OR: [
              { human_friendly_id: { contains: upperSearchTerm } },
              { first_name: { contains: searchTerm } },
              { last_name: { contains: searchTerm } },
              {
                contacts: {
                  some: {
                    deleted_at: null,
                    value: { contains: searchTerm },
                  },
                },
              },
              {
                identifiers: {
                  some: {
                    deleted_at: null,
                    identifier_value: { contains: searchTerm },
                  },
                },
              },
            ],
          },
        },
        {
          provider: {
            OR: [
              { human_friendly_id: { contains: upperSearchTerm } },
              { email: { contains: searchTerm } },
              { phone: { contains: searchTerm } },
              {
                profile: {
                  is: {
                    OR: [
                      { first_name: { contains: searchTerm } },
                      { middle_name: { contains: searchTerm } },
                      { last_name: { contains: searchTerm } },
                    ],
                  },
                },
              },
            ],
          },
        },
      ];
    }

    const [appointments, total] = await Promise.all([
      appointmentRepository.findMany(whereClause, skip, limit, orderBy, APPOINTMENT_INCLUDE),
      appointmentRepository.count(whereClause)
    ]);

    return {
      appointments: withAppointmentProjectionList(appointments),
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
 * Get appointment by ID
 *
 * @param {string} id - Appointment ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Appointment data
 */
const getAppointmentById = async (id, userId, ipAddress) => {
  try {
    const appointment = await resolveAppointmentRecordByIdentifier(id);

    if (!appointment) {
      throw new HttpError('errors.appointment.not_found', 404);
    }

    return appointment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new appointment
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Appointment data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created appointment
 */
const createAppointment = async (data, userId, ipAddress) => {
  try {
    const payload = await resolveAppointmentPayloadIdentifiers(data);
    const createdAppointment = await appointmentRepository.create(payload);
    const appointment = await appointmentRepository.findById(createdAppointment.id, APPOINTMENT_INCLUDE);
    const projectedAppointment = withAppointmentProjection(appointment || createdAppointment);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'appointment',
      entity_id: createdAppointment.id,
      diff: { after: projectedAppointment },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedAppointment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update appointment
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Appointment ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated appointment
 */
const updateAppointment = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await resolveAppointmentRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment.not_found', 404);
    }

    const payload = await resolveAppointmentPayloadIdentifiers(data, before);
    const updatedAppointment = await appointmentRepository.update(before.id, payload);
    const appointment = await appointmentRepository.findById(updatedAppointment.id, APPOINTMENT_INCLUDE);
    const projectedAppointment = withAppointmentProjection(appointment || updatedAppointment);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'appointment',
      entity_id: updatedAppointment.id,
      diff: { before, after: projectedAppointment },
      ip_address: ipAddress
    }).catch(() => {});

    await maybeAutoStartOpdFlow({
      before,
      appointment: projectedAppointment,
      updateData: payload,
      userId,
      ipAddress,
    });

    return projectedAppointment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete appointment (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Appointment ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteAppointment = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await resolveAppointmentRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment.not_found', 404);
    }

    await appointmentRepository.softDelete(before.id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'appointment',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Cancel appointment (action endpoint)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Appointment ID
 * @param {string} reason - Cancellation reason (optional)
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Cancelled appointment
 */
const cancelAppointment = async (id, reason, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await resolveAppointmentRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.appointment.not_found', 404);
    }

    // Check if already cancelled
    if (before.status === 'CANCELLED') {
      throw new HttpError('errors.appointment.already_cancelled', 400);
    }

    // Update to cancelled status
    const updateData = {
      status: 'CANCELLED'
    };

    // Optionally append cancellation reason to existing reason
    if (reason) {
      updateData.reason = before.reason 
        ? `${before.reason}\nCancellation reason: ${reason}`
        : `Cancellation reason: ${reason}`;
    }

    const cancelledAppointment = await appointmentRepository.update(before.id, updateData);
    const appointment = await appointmentRepository.findById(cancelledAppointment.id, APPOINTMENT_INCLUDE);
    const projectedAppointment = withAppointmentProjection(appointment || cancelledAppointment);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CANCEL',
      entity: 'appointment',
      entity_id: cancelledAppointment.id,
      diff: { before, after: projectedAppointment },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedAppointment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listAppointments,
  getAppointmentById,
  createAppointment,
  updateAppointment,
  deleteAppointment,
  cancelAppointment
};
