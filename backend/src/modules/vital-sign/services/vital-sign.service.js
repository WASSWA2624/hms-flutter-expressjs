/**
 * Vital Sign service
 *
 * @module modules/vital-sign/services
 * @description Business logic layer for vital sign operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const vitalSignRepository = require('@repositories/vital-sign/vital-sign.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const clinicalAlertThresholdService = require('@services/clinical-alert-threshold/clinical-alert-threshold.service');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const BLOOD_PRESSURE_VALUE_REGEX = /^(\d{2,3}(?:\.\d{1,2})?)\s*\/\s*(\d{2,3}(?:\.\d{1,2})?)$/;

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit),
  hasNextPage: page < Math.ceil(total / limit),
  hasPreviousPage: page > 1,
});

const buildEmptyListResult = (page, limit) => ({
  vitalSigns: [],
  pagination: buildPagination(page, limit, 0),
});

const resolveVitalSignId = (id) =>
  resolveIdentifierForPayload({
    value: id,
    field: 'id',
    model: 'vital_sign',
    where: { deleted_at: null },
  });

const toFiniteNumber = (value) => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toNumber === 'function') {
    const parsed = value.toNumber();
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

const roundToTwo = (value) => {
  if (!Number.isFinite(value)) return null;
  return Math.round(value * 100) / 100;
};

const formatBpComponent = (value) => {
  const rounded = roundToTwo(value);
  if (!Number.isFinite(rounded)) return '';
  return Number.isInteger(rounded) ? String(rounded) : String(rounded);
};

const parseLegacyBpValue = (value) => {
  const match = String(value || '').trim().match(BLOOD_PRESSURE_VALUE_REGEX);
  if (!match) return null;

  const systolic = roundToTwo(toFiniteNumber(match[1]));
  const diastolic = roundToTwo(toFiniteNumber(match[2]));

  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) {
    return null;
  }

  return { systolic, diastolic };
};

const computeMap = (systolic, diastolic) => {
  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) return null;
  return roundToTwo((systolic + 2 * diastolic) / 3);
};

const normalizeBloodPressurePayload = (input = {}) => {
  const parsedLegacy = parseLegacyBpValue(input.value);
  const systolic =
    roundToTwo(toFiniteNumber(input.systolic_value)) ?? parsedLegacy?.systolic ?? null;
  const diastolic =
    roundToTwo(toFiniteNumber(input.diastolic_value)) ?? parsedLegacy?.diastolic ?? null;

  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) {
    throw new HttpError('errors.validation.required', 400, [
      { field: 'systolic_value' },
      { field: 'diastolic_value' },
    ]);
  }

  const mapValue = roundToTwo(toFiniteNumber(input.map_value)) ?? computeMap(systolic, diastolic);
  return {
    value: `${formatBpComponent(systolic)}/${formatBpComponent(diastolic)}`,
    systolic_value: systolic,
    diastolic_value: diastolic,
    map_value: mapValue,
  };
};

const assertNoDuplicateVitalSignForEncounter = async ({
  encounterId,
  vitalType,
  excludeId = null,
}) => {
  const normalizedEncounterId = String(encounterId || '').trim();
  const normalizedVitalType = String(vitalType || '').trim().toUpperCase();
  if (!normalizedEncounterId || !normalizedVitalType) return;

  const matches = await vitalSignRepository.findMany(
    {
      encounter_id: normalizedEncounterId,
      vital_type: normalizedVitalType,
    },
    0,
    2,
    { recorded_at: 'desc' }
  );

  const duplicate = matches.find((entry) => entry.id !== excludeId);
  if (duplicate) {
    throw new HttpError('errors.vital_sign.duplicate_for_encounter', 409, [
      { field: 'vital_type' },
      { field: 'encounter_id' },
    ]);
  }
};

const normalizeVitalSignPayload = (input = {}, existing = null) => {
  const source = { ...(existing || {}), ...(input || {}) };
  const vitalType = String(source.vital_type || '').trim().toUpperCase();
  const normalized = { ...input };

  if (vitalType === 'BLOOD_PRESSURE') {
    const normalizedBp = normalizeBloodPressurePayload(source);
    normalized.value = normalizedBp.value;
    normalized.systolic_value = normalizedBp.systolic_value;
    normalized.diastolic_value = normalizedBp.diastolic_value;
    normalized.map_value = normalizedBp.map_value;
    return normalized;
  }

  if (normalized.value !== undefined) {
    normalized.value = String(normalized.value || '').trim();
  }

  if (normalized.vital_type && String(normalized.vital_type).trim().toUpperCase() !== 'BLOOD_PRESSURE') {
    normalized.systolic_value = null;
    normalized.diastolic_value = null;
    normalized.map_value = null;
  }

  return normalized;
};

const resolveVitalSignPayload = async (input = {}) => {
  const payload = { ...input };
  if (Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
    payload.encounter_id = await resolveIdentifierForPayload({
      value: payload.encounter_id,
      field: 'encounter_id',
      model: 'encounter',
      where: { deleted_at: null },
    });
  }
  return payload;
};

/**
 * List vital signs with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Vital signs and pagination data
 */
const listVitalSigns = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { recorded_at: 'desc' };

    // Build filter object
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
    if (filters.vital_type) whereClause.vital_type = filters.vital_type;

    const [vitalSigns, total] = await Promise.all([
      vitalSignRepository.findMany(whereClause, skip, limit, orderBy),
      vitalSignRepository.count(whereClause)
    ]);

    return {
      vitalSigns,
      pagination: buildPagination(page, limit, total)
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get vital sign by ID
 *
 * @param {string} id - Vital sign ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Vital sign data
 */
const getVitalSignById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveVitalSignId(id);
    const vitalSign = await vitalSignRepository.findById(resolvedId);

    if (!vitalSign) {
      throw new HttpError('errors.vital_sign.not_found', 404);
    }

    return vitalSign;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new vital sign
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Vital sign data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created vital sign
 */
const createVitalSign = async (data, userId, ipAddress) => {
  try {
    const resolvedPayload = await resolveVitalSignPayload(data);
    if (!resolvedPayload.recorded_at) {
      resolvedPayload.recorded_at = new Date();
    }
    const normalizedPayload = normalizeVitalSignPayload(resolvedPayload);
    await assertNoDuplicateVitalSignForEncounter({
      encounterId: normalizedPayload.encounter_id,
      vitalType: normalizedPayload.vital_type,
    });
    const vitalSign = await vitalSignRepository.create(normalizedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'vital_sign',
      entity_id: vitalSign.id,
      diff: { after: vitalSign },
      ip_address: ipAddress
    }).catch(() => {});

    // Automatic alert evaluation should not block vital capture.
    try {
      const encounter = await prisma.encounter.findFirst({
        where: { id: vitalSign.encounter_id, deleted_at: null },
        include: { patient: true },
      });
      if (encounter) {
        await clinicalAlertThresholdService.evaluateVitalAndCreateAlerts(
          {
            vitalSign,
            encounter,
            patient: encounter.patient || null,
          },
          {
            user_id: userId,
            ip_address: ipAddress,
          }
        );
      }
    } catch (_error) {
      // Auto-rule failure should not fail manual clinical documentation.
    }

    return vitalSign;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update vital sign
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Vital sign ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated vital sign
 */
const updateVitalSign = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const resolvedId = await resolveVitalSignId(id);
    const before = await vitalSignRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.vital_sign.not_found', 404);
    }

    const resolvedPayload = await resolveVitalSignPayload(data);
    const normalizedPayload = normalizeVitalSignPayload(resolvedPayload, before);
    const normalizedEncounterId = normalizedPayload.encounter_id || before.encounter_id;
    const normalizedVitalType = normalizedPayload.vital_type || before.vital_type;
    const encounterChanged =
      normalizedPayload.encounter_id !== undefined && normalizedPayload.encounter_id !== before.encounter_id;
    const vitalTypeChanged =
      normalizedPayload.vital_type !== undefined && normalizedPayload.vital_type !== before.vital_type;

    if (encounterChanged || vitalTypeChanged) {
      await assertNoDuplicateVitalSignForEncounter({
        encounterId: normalizedEncounterId,
        vitalType: normalizedVitalType,
        excludeId: resolvedId,
      });
    }
    const vitalSign = await vitalSignRepository.update(
      resolvedId,
      normalizedPayload
    );

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'vital_sign',
      entity_id: vitalSign.id,
      diff: { before, after: vitalSign },
      ip_address: ipAddress
    }).catch(() => {});

    return vitalSign;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete vital sign (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Vital sign ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteVitalSign = async (id, data = {}, userId, ipAddress) => {
  try {
    const deletionReason = String(data?.reason || '').trim();
    if (!deletionReason) {
      throw new HttpError('errors.validation.required', 400, [
        { field: 'reason' },
      ]);
    }

    // Get current state for audit
    const resolvedId = await resolveVitalSignId(id);
    const before = await vitalSignRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.vital_sign.not_found', 404);
    }

    await vitalSignRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'vital_sign',
      entity_id: resolvedId,
      diff: { before, deletion_reason: deletionReason },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listVitalSigns,
  getVitalSignById,
  createVitalSign,
  updateVitalSign,
  deleteVitalSign
};
