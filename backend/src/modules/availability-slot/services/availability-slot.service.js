/**
 * Availability slot service
 *
 * @module modules/availability-slot/services
 * @description Business logic layer for availability slot operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const availabilitySlotRepository = require('@repositories/availability-slot/availability-slot.repository');
const { createAuditLog } = require('@lib/audit');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const ALLOWED_AVAILABILITY_SLOT_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'override_date',
  'start_time',
  'end_time',
  'is_available',
]);

const resolveSortBy = (value, fallback = 'created_at') => {
  const normalized = String(value || '').trim();
  return ALLOWED_AVAILABILITY_SLOT_SORT_FIELDS.has(normalized) ? normalized : fallback;
};

const resolveSortOrder = (value, fallback = 'desc') => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'asc' || normalized === 'desc') return normalized;
  return fallback;
};

const AVAILABILITY_SLOT_INCLUDE = {
  schedule: {
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

const normalizeBooleanFilter = (value) => {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (normalized === 'true') return true;
  if (normalized === 'false') return false;
  return null;
};

const withAvailabilitySlotProjection = (slot) => {
  if (!slot || typeof slot !== 'object') return slot;

  const projected = { ...slot };
  appendIfPresent(
    projected,
    'schedule_id',
    resolvePublicIdentifier(slot?.schedule?.human_friendly_id, slot?.schedule_id)
  );
  appendIfPresent(projected, 'schedule_human_friendly_id', slot?.schedule?.human_friendly_id);
  appendIfPresent(projected, 'tenant_human_friendly_id', slot?.schedule?.tenant?.human_friendly_id);
  appendIfPresent(projected, 'tenant_name', slot?.schedule?.tenant?.name);
  appendIfPresent(projected, 'facility_human_friendly_id', slot?.schedule?.facility?.human_friendly_id);
  appendIfPresent(projected, 'facility_name', slot?.schedule?.facility?.name);
  appendIfPresent(projected, 'provider_human_friendly_id', slot?.schedule?.provider?.human_friendly_id);
  appendIfPresent(
    projected,
    'provider_display_name',
    resolveDisplayName(
      slot?.schedule?.provider?.profile?.first_name,
      slot?.schedule?.provider?.profile?.middle_name,
      slot?.schedule?.provider?.profile?.last_name
    )
  );
  appendIfPresent(projected, 'provider_email', slot?.schedule?.provider?.email);
  appendIfPresent(projected, 'provider_phone', slot?.schedule?.provider?.phone);
  return projected;
};

const withAvailabilitySlotProjectionList = (slots = []) =>
  (Array.isArray(slots) ? slots : []).map((slot) => withAvailabilitySlotProjection(slot));

const buildEmptyListResult = (page, limit) => ({
  slots: [],
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

const resolvePayloadIdentifier = async ({ value, field, model, where = {}, nullable = false }) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
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

const toDateValue = ({ value, field, nullable = false }) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }

  return parsed;
};

const assertTimeWindow = (startTime, endTime) => {
  if (!startTime || !endTime) return;
  if (startTime.getTime() >= endTime.getTime()) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'start_time' }, { field: 'end_time' }]);
  }
};

const resolveAvailabilityPayload = async (data = {}, existing = null) => {
  const payload = { ...data };

  if (payload.schedule_id !== undefined) {
    payload.schedule_id = await resolvePayloadIdentifier({
      value: payload.schedule_id,
      field: 'schedule_id',
      model: 'provider_schedule',
    });
  }

  if (payload.override_date !== undefined) {
    payload.override_date = toDateValue({
      value: payload.override_date,
      field: 'override_date',
      nullable: true,
    });
  }

  const startTime =
    payload.start_time !== undefined
      ? toDateValue({ value: payload.start_time, field: 'start_time' })
      : existing?.start_time;
  const endTime =
    payload.end_time !== undefined
      ? toDateValue({ value: payload.end_time, field: 'end_time' })
      : existing?.end_time;

  assertTimeWindow(startTime, endTime);

  if (payload.start_time !== undefined) {
    payload.start_time = startTime;
  }
  if (payload.end_time !== undefined) {
    payload.end_time = endTime;
  }

  return payload;
};

const resolveAvailabilitySlotRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'availability_slot',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  const slot = await availabilitySlotRepository.findById(resolved.id, AVAILABILITY_SLOT_INCLUDE);
  return withAvailabilitySlotProjection(slot);
};

/**
 * List availability slots with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Availability slots and pagination data
 */
const listAvailabilitySlots = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const resolvedSortBy = resolveSortBy(sortBy, 'created_at');
    const resolvedOrder = resolveSortOrder(order, 'desc');
    const orderBy = { [resolvedSortBy]: resolvedOrder };

    // Build filter object
    const whereClause = {};
    
    const scheduleId = await resolveFilterIdentifier({
      value: filters.schedule_id,
      model: 'provider_schedule',
    });
    if (filters.schedule_id !== undefined && scheduleId === null) {
      return buildEmptyListResult(page, limit);
    }
    if (scheduleId) whereClause.schedule_id = scheduleId;

    if (filters.override_date) {
      const overrideDate = new Date(filters.override_date);
      const dayStart = new Date(overrideDate);
      dayStart.setUTCHours(0, 0, 0, 0);
      const dayEnd = new Date(overrideDate);
      dayEnd.setUTCHours(23, 59, 59, 999);
      whereClause.override_date = {
        gte: dayStart,
        lte: dayEnd,
      };
    }

    const isAvailableFilter = normalizeBooleanFilter(filters.is_available);
    if (filters.is_available !== undefined && isAvailableFilter === null) {
      return buildEmptyListResult(page, limit);
    }
    if (isAvailableFilter !== undefined) whereClause.is_available = isAvailableFilter;

    const [slots, total] = await Promise.all([
      availabilitySlotRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        AVAILABILITY_SLOT_INCLUDE
      ),
      availabilitySlotRepository.count(whereClause)
    ]);

    return {
      slots: withAvailabilitySlotProjectionList(slots),
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
 * Get availability slot by ID
 *
 * @param {string} id - Availability slot ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Availability slot data
 */
const getAvailabilitySlotById = async (id, userId, ipAddress) => {
  try {
    const slot = await resolveAvailabilitySlotRecordByIdentifier(id);

    if (!slot) {
      throw new HttpError('errors.availability_slot.not_found', 404);
    }

    return slot;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new availability slot
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Availability slot data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created availability slot
 */
const createAvailabilitySlot = async (data, userId, ipAddress) => {
  try {
    const payload = await resolveAvailabilityPayload(data);
    const createdSlot = await availabilitySlotRepository.create(payload);
    const slot = await availabilitySlotRepository.findById(createdSlot.id, AVAILABILITY_SLOT_INCLUDE);
    const projectedSlot = withAvailabilitySlotProjection(slot || createdSlot);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'availability_slot',
      entity_id: createdSlot.id,
      diff: { after: projectedSlot },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedSlot;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update availability slot
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Availability slot ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated availability slot
 */
const updateAvailabilitySlot = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await resolveAvailabilitySlotRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.availability_slot.not_found', 404);
    }

    const payload = await resolveAvailabilityPayload(data, before);
    const updatedSlot = await availabilitySlotRepository.update(before.id, payload);
    const slot = await availabilitySlotRepository.findById(updatedSlot.id, AVAILABILITY_SLOT_INCLUDE);
    const projectedSlot = withAvailabilitySlotProjection(slot || updatedSlot);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'availability_slot',
      entity_id: updatedSlot.id,
      diff: { before, after: projectedSlot },
      ip_address: ipAddress
    }).catch(() => {});

    return projectedSlot;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete availability slot (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Availability slot ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteAvailabilitySlot = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await resolveAvailabilitySlotRecordByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.availability_slot.not_found', 404);
    }

    await availabilitySlotRepository.softDelete(before.id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'availability_slot',
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
  listAvailabilitySlots,
  getAvailabilitySlotById,
  createAvailabilitySlot,
  updateAvailabilitySlot,
  deleteAvailabilitySlot
};
