/**
 * Referral service
 *
 * @module modules/referral/services
 * @description Business logic layer for referral operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const referralRepository = require('@repositories/referral/referral.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const REFERRAL_TRANSITIONS = Object.freeze({
  REQUESTED: new Set(['APPROVED', 'CANCELLED']),
  APPROVED: new Set(['IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
  IN_PROGRESS: new Set(['COMPLETED', 'CANCELLED']),
  COMPLETED: new Set([]),
  CANCELLED: new Set([]),
});

const sanitizeString = (value) => (typeof value === 'string' ? value.trim() : '');

const REFERRAL_WITH_RELATIONS_INCLUDE = {
  encounter: {
    select: {
      id: true,
      human_friendly_id: true,
    },
  },
  from_department: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      short_name: true,
      department_type: true,
    },
  },
  to_department: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      short_name: true,
      department_type: true,
    },
  },
};

const mapReferralRecord = (record) => {
  if (!record || typeof record !== 'object') return record;
  const fromDepartment = record.from_department || null;
  const toDepartment = record.to_department || null;

  return {
    ...record,
    encounter_display_id:
      sanitizeString(record.encounter?.human_friendly_id) ||
      sanitizeString(record.encounter_id),
    from_department_name:
      sanitizeString(fromDepartment?.name) ||
      sanitizeString(fromDepartment?.short_name),
    from_department_display_id:
      sanitizeString(fromDepartment?.human_friendly_id) ||
      sanitizeString(record.from_department_id),
    to_department_name:
      sanitizeString(toDepartment?.name) || sanitizeString(toDepartment?.short_name),
    to_department_display_id:
      sanitizeString(toDepartment?.human_friendly_id) ||
      sanitizeString(record.to_department_id),
  };
};

const fetchReferralForClinicalDisplay = async (id) =>
  mapReferralRecord(
    await referralRepository.findById(id, REFERRAL_WITH_RELATIONS_INCLUDE)
  );

const normalizeNullableText = (value) => {
  if (value === undefined) return undefined;
  if (value === null) return null;
  const normalized = sanitizeString(value);
  return normalized || null;
};

const canTransitionReferral = (fromStatus, toStatus) => {
  const normalizedFrom = String(fromStatus || '').trim().toUpperCase();
  const normalizedTo = String(toStatus || '').trim().toUpperCase();
  const allowed = REFERRAL_TRANSITIONS[normalizedFrom];
  if (!allowed) return false;
  return allowed.has(normalizedTo);
};

const assertTransitionOrThrow = (fromStatus, toStatus) => {
  if (!canTransitionReferral(fromStatus, toStatus)) {
    throw new HttpError('errors.referral.invalid_status_transition', 400, [
      { field: 'status' },
      { from: fromStatus },
      { to: toStatus },
    ]);
  }
};

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit),
  hasNextPage: page < Math.ceil(total / limit),
  hasPreviousPage: page > 1,
});

const buildEmptyListResult = (page, limit) => ({
  referrals: [],
  pagination: buildPagination(page, limit, 0),
});

const resolveReferralPayload = async (data = {}, { isCreate = false } = {}) => {
  const payload = { ...data };

  if (isCreate || Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
    payload.encounter_id = await resolveIdentifierForPayload({
      value: payload.encounter_id,
      field: 'encounter_id',
      model: 'encounter',
      where: { deleted_at: null },
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'from_department_id')) {
    payload.from_department_id = await resolveIdentifierForPayload({
      value: payload.from_department_id,
      field: 'from_department_id',
      model: 'department',
      where: { deleted_at: null },
      nullable: true,
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'to_department_id')) {
    payload.to_department_id = await resolveIdentifierForPayload({
      value: payload.to_department_id,
      field: 'to_department_id',
      model: 'department',
      where: { deleted_at: null },
      nullable: true,
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'external_facility_name')) {
    payload.external_facility_name = sanitizeString(payload.external_facility_name);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'reason')) {
    payload.reason = sanitizeString(payload.reason);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'referral_reason_code')) {
    payload.referral_reason_code = normalizeNullableText(payload.referral_reason_code);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'custom_reason')) {
    payload.custom_reason = normalizeNullableText(payload.custom_reason);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'notes')) {
    payload.notes = normalizeNullableText(payload.notes);
  }

  return payload;
};

/**
 * List referrals with pagination and filtering
 */
const listReferrals = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    if (filters.encounter_id) {
      const encounterId = await resolveIdentifierForFilter({
        value: filters.encounter_id,
        model: 'encounter',
        where: { deleted_at: null },
      });
      if (encounterId === null) return buildEmptyListResult(page, limit);
      if (encounterId !== undefined) whereClause.encounter_id = encounterId;
    }
    if (filters.from_department_id) {
      const fromDepartmentId = await resolveIdentifierForFilter({
        value: filters.from_department_id,
        model: 'department',
        where: { deleted_at: null },
      });
      if (fromDepartmentId === null) return buildEmptyListResult(page, limit);
      if (fromDepartmentId !== undefined) whereClause.from_department_id = fromDepartmentId;
    }
    if (filters.to_department_id) {
      const toDepartmentId = await resolveIdentifierForFilter({
        value: filters.to_department_id,
        model: 'department',
        where: { deleted_at: null },
      });
      if (toDepartmentId === null) return buildEmptyListResult(page, limit);
      if (toDepartmentId !== undefined) whereClause.to_department_id = toDepartmentId;
    }
    if (filters.external_facility_name) {
      whereClause.external_facility_name = {
        contains: sanitizeString(filters.external_facility_name),
      };
    }
    if (filters.referral_reason_code) {
      whereClause.referral_reason_code = sanitizeString(filters.referral_reason_code);
    }
    if (filters.status) whereClause.status = filters.status;

    const [referrals, total] = await Promise.all([
      referralRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        REFERRAL_WITH_RELATIONS_INCLUDE
      ),
      referralRepository.count(whereClause),
    ]);

    return {
      referrals: referrals.map(mapReferralRecord),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get referral by ID
 */
const getReferralById = async (id, userId, ipAddress) => {
  try {
    const referral = await referralRepository.findById(id, REFERRAL_WITH_RELATIONS_INCLUDE);

    if (!referral) {
      throw new HttpError('errors.referral.not_found', 404);
    }

    return mapReferralRecord(referral);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new referral
 * Per prisma.mdc: Mutations must create audit logs
 */
const createReferral = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...(await resolveReferralPayload(data, { isCreate: true })),
      status: 'REQUESTED',
    };

    const referral = await referralRepository.create(payload);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'referral',
      entity_id: referral.id,
      diff: { after: referral },
      ip_address: ipAddress,
    }).catch(() => {});

    return fetchReferralForClinicalDisplay(referral.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update referral
 * Per prisma.mdc: Mutations must create audit logs
 */
const updateReferral = async (id, data, userId, ipAddress) => {
  try {
    const before = await referralRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.referral.not_found', 404);
    }

    const payload = await resolveReferralPayload(data);

    if (payload.status) {
      const nextStatus = String(payload.status || '').trim().toUpperCase();
      if (nextStatus !== before.status) {
        assertTransitionOrThrow(before.status, nextStatus);
      }
      payload.status = nextStatus;
    }

    const referral = await referralRepository.update(id, payload);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'referral',
      entity_id: referral.id,
      diff: { before, after: referral },
      ip_address: ipAddress,
    }).catch(() => {});

    return fetchReferralForClinicalDisplay(referral.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete referral (soft delete)
 */
const deleteReferral = async (id, userId, ipAddress) => {
  try {
    const before = await referralRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.referral.not_found', 404);
    }

    await referralRepository.softDelete(id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'referral',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Redeem referral
 */
const redeemReferral = async (id, data = {}, userId, ipAddress) => {
  try {
    const before = await referralRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.referral.not_found', 404);
    }

    if (before.status === 'COMPLETED') {
      throw new HttpError('errors.referral.already_redeemed', 400);
    }

    assertTransitionOrThrow(before.status, 'COMPLETED');

    const referral = await referralRepository.update(id, { status: 'COMPLETED' });

    createAuditLog({
      user_id: userId,
      action: 'REDEEM',
      entity: 'referral',
      entity_id: referral.id,
      diff: {
        before,
        after: referral,
        metadata: {
          notes: data.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return fetchReferralForClinicalDisplay(referral.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const transitionReferral = async (id, targetStatus, data = {}, userId, ipAddress, action = 'UPDATE') => {
  try {
    const before = await referralRepository.findById(id);
    if (!before) {
      throw new HttpError('errors.referral.not_found', 404);
    }

    const normalizedStatus = String(targetStatus || '').trim().toUpperCase();
    if (before.status === normalizedStatus) {
      return fetchReferralForClinicalDisplay(before.id);
    }

    assertTransitionOrThrow(before.status, normalizedStatus);
    const referral = await referralRepository.update(id, { status: normalizedStatus });

    createAuditLog({
      user_id: userId,
      action,
      entity: 'referral',
      entity_id: referral.id,
      diff: {
        before,
        after: referral,
        metadata: { notes: data?.notes || null },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return fetchReferralForClinicalDisplay(referral.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const approveReferral = async (id, data = {}, userId, ipAddress) =>
  transitionReferral(id, 'APPROVED', data, userId, ipAddress, 'APPROVE');

const startReferral = async (id, data = {}, userId, ipAddress) =>
  transitionReferral(id, 'IN_PROGRESS', data, userId, ipAddress, 'START');

const cancelReferral = async (id, data = {}, userId, ipAddress) =>
  transitionReferral(id, 'CANCELLED', data, userId, ipAddress, 'CANCEL');

module.exports = {
  listReferrals,
  getReferralById,
  createReferral,
  updateReferral,
  deleteReferral,
  redeemReferral,
  approveReferral,
  startReferral,
  cancelReferral,
};
