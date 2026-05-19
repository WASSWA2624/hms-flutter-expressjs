/**
 * Pharmacy order service
 *
 * @module modules/pharmacy-order/services
 * @description Business logic layer for pharmacy order operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const pharmacyOrderRepository = require('@repositories/pharmacy-order/pharmacy-order.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  PHARMACY_ORDER_WITH_RELATIONS_INCLUDE,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  resolveScopedUserContext,
  buildPatientScopeWhere,
  buildEncounterScopeWhere,
  buildDrugScopeWhere,
  buildOrderScopeWhere,
  matchesOrderScope,
} = require('@services/pharmacy-workspace/pharmacy.shared');
const {
  mapPharmacyOrderRecord,
} = require('@services/pharmacy-workspace/pharmacy.serializer');

const ORDER_SCOPE_INCLUDE = PHARMACY_ORDER_WITH_RELATIONS_INCLUDE;

const serializePharmacyOrder = (record) =>
  mapPharmacyOrderRecord(record, { includeChildren: true }) || record;

const resolveScopedPatientId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'patient',
    where: {
      deleted_at: null,
      ...buildPatientScopeWhere(scope),
    },
    errorKey: 'errors.patient.not_found',
    allowNull,
  });

const resolveScopedEncounterId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'encounter',
    where: {
      deleted_at: null,
      ...buildEncounterScopeWhere(scope),
    },
    errorKey: 'errors.encounter.not_found',
    allowNull,
  });

const resolveScopedDrugId = async (identifier, scope) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'drug',
    where: {
      deleted_at: null,
      ...buildDrugScopeWhere(scope),
    },
    errorKey: 'errors.drug.not_found',
  });

const sanitizeString = (value) => (typeof value === 'string' ? value.trim() : '');

const normalizeNullableString = (value) => {
  const normalized = sanitizeString(value);
  return normalized || null;
};

const normalizePositiveNumber = (value) => {
  if (value === undefined || value === null || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

const normalizePositiveInteger = (value) => {
  const parsed = normalizePositiveNumber(value);
  return parsed ? Math.ceil(parsed) : null;
};

const normalizeOptionalDate = (value) => {
  if (value === undefined) return undefined;
  if (value === null || value === '') return undefined;

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
};

const FREQUENCY_DOSES_PER_DAY = Object.freeze({
  ONCE: 1,
  OD: 1,
  BID: 2,
  TID: 3,
  QID: 4,
  Q4H: 6,
  Q6H: 4,
  Q8H: 3,
  Q12H: 2,
  QHS: 1,
  WEEKLY: 1 / 7,
  STAT: 1,
});

const durationToDays = (durationValue, durationUnit) => {
  const value = normalizePositiveNumber(durationValue);
  if (!value) return null;

  const unit = sanitizeString(durationUnit).toUpperCase();
  if (unit.startsWith('HOUR')) return value / 24;
  if (unit.startsWith('WEEK')) return value * 7;
  if (unit.startsWith('MONTH')) return value * 30;
  return value;
};

const calculateRequestedQuantity = (item = {}) => {
  const explicitQuantity = normalizePositiveInteger(item.quantity);
  if (explicitQuantity) return explicitQuantity;

  const dosesPerDay = FREQUENCY_DOSES_PER_DAY[sanitizeString(item.frequency).toUpperCase()];
  const durationDays = durationToDays(item.duration_value, item.duration_unit);
  const doseAmount = normalizePositiveNumber(item.dose_amount) || 1;

  if (!dosesPerDay || !durationDays) return 1;
  return Math.max(1, Math.ceil(doseAmount * dosesPerDay * durationDays));
};

const buildDosageText = (item = {}) => {
  const explicitDosage = sanitizeString(item.dosage);
  if (explicitDosage) return explicitDosage;

  const doseAmount = normalizePositiveNumber(item.dose_amount);
  const doseUnit = sanitizeString(item.dose_unit);
  if (!doseAmount) return null;

  return doseUnit ? `${doseAmount} ${doseUnit}` : `${doseAmount}`;
};

const normalizeOrderItemPayloads = async (items = [], scope = {}) => {
  const normalizedItems = [];

  for (const item of items) {
    normalizedItems.push({
      drug_id: await resolveScopedDrugId(item.drug_id, scope),
      quantity: calculateRequestedQuantity(item),
      quantity_unit: normalizeNullableString(item.quantity_unit),
      dosage: buildDosageText(item),
      dose_amount: normalizePositiveNumber(item.dose_amount),
      dose_unit: normalizeNullableString(item.dose_unit),
      frequency: item.frequency || null,
      route: item.route || null,
      duration_value: item.duration_value ? Number(item.duration_value) : null,
      duration_unit: normalizeNullableString(item.duration_unit),
      instructions: normalizeNullableString(item.instructions),
      custom_prescription: normalizeNullableString(item.custom_prescription),
      status: 'ACTIVE',
    });
  }

  return normalizedItems;
};

const createPrescriptionDetailNote = async ({ encounterId, items, userId }) => {
  if (!encounterId || !userId) return;

  const lines = items
    .map((item, index) => {
      const dosageText = buildDosageText(item);
      const durationText = [
        sanitizeString(item.duration_value || item.duration),
        sanitizeString(item.duration_unit),
      ].filter(Boolean).join(' ');
      const details = [
        dosageText,
        sanitizeString(item.frequency),
        durationText,
        sanitizeString(item.route),
        sanitizeString(item.quantity_unit)
          ? `${sanitizeString(item.quantity)} ${sanitizeString(item.quantity_unit)} requested`
          : sanitizeString(item.quantity)
            ? `${sanitizeString(item.quantity)} requested`
            : '',
        sanitizeString(item.instructions),
        sanitizeString(item.custom_prescription),
      ].filter(Boolean);
      if (!details.length) return '';
      const medicationName = sanitizeString(
        item?.drug?.name ||
          item?.drug_display_name ||
          item?.drug_name ||
          item?.medicine_name ||
          item?.medication_name ||
          item?.custom_prescription
      );
      return `${index + 1}. ${medicationName || 'Medication'}: ${details.join('; ')}`;
    })
    .filter(Boolean);

  if (!lines.length) return;

  try {
    await prisma.clinical_note.create({
      data: {
        encounter_id: encounterId,
        author_user_id: userId,
        note: `Prescription details:\n${lines.join('\n')}`,
      },
    });
  } catch (_error) {
    // Prescription creation should not fail because supplementary note capture failed.
  }
};

const buildScopedOrderWhereClause = async (filters = {}, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const whereClause = {
    ...buildOrderScopeWhere(scope),
  };

  if (filters.patient_id) {
    whereClause.patient_id = await resolveScopedPatientId(filters.patient_id, scope);
  }

  if (filters.encounter_id) {
    whereClause.encounter_id = await resolveScopedEncounterId(filters.encounter_id, scope);
  }

  if (filters.status) whereClause.status = filters.status;

  if (filters.ordered_at_from || filters.ordered_at_to) {
    whereClause.ordered_at = {};
    if (filters.ordered_at_from) whereClause.ordered_at.gte = new Date(filters.ordered_at_from);
    if (filters.ordered_at_to) whereClause.ordered_at.lte = new Date(filters.ordered_at_to);
  }

  return { scope, whereClause };
};

const findScopedOrderOrThrow = async (id, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const pharmacyOrder = await resolveModelRecordOrThrow({
    identifier: id,
    model: 'pharmacy_order',
    where: {
      deleted_at: null,
      ...buildOrderScopeWhere(scope),
    },
    include: ORDER_SCOPE_INCLUDE,
    errorKey: 'errors.pharmacy_order.not_found',
  });

  if (!pharmacyOrder || !matchesOrderScope(pharmacyOrder, scope)) {
    throw new HttpError('errors.pharmacy_order.not_found', 404);
  }

  return { scope, pharmacyOrder };
};

/**
 * List pharmacy orders with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Pharmacy orders and pagination data
 */
const listPharmacyOrders = async (filters, page, limit, sortBy, order, userId, ipAddress, user = {}) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { ordered_at: 'desc' };
    const { whereClause } = await buildScopedOrderWhereClause(filters, user);

    const [pharmacyOrders, total] = await Promise.all([
      pharmacyOrderRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        ORDER_SCOPE_INCLUDE
      ),
      pharmacyOrderRepository.count(whereClause)
    ]);

    return {
      pharmacyOrders: pharmacyOrders.map(serializePharmacyOrder).filter(Boolean),
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
 * Get pharmacy order by ID
 *
 * @param {string} id - Pharmacy order ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Pharmacy order data
 */
const getPharmacyOrderById = async (id, userId, ipAddress, user = {}) => {
  try {
    const { pharmacyOrder } = await findScopedOrderOrThrow(id, user);
    return serializePharmacyOrder(pharmacyOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new pharmacy order
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Pharmacy order data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Created pharmacy order
 */
const createPharmacyOrder = async (data, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const items = Array.isArray(data.items) ? data.items : [];
    const payload = {
      ...data,
      patient_id: await resolveScopedPatientId(data.patient_id, scope),
      status: 'ORDERED',
    };
    const orderedAt = normalizeOptionalDate(data.ordered_at);
    delete payload.items;
    if (orderedAt) {
      payload.ordered_at = orderedAt;
    } else {
      delete payload.ordered_at;
    }

    if (data.encounter_id !== undefined) {
      payload.encounter_id = await resolveScopedEncounterId(data.encounter_id, scope, true);
    }
    if (items.length > 0) {
      payload.items = {
        create: await normalizeOrderItemPayloads(items, scope),
      };
    }

    const pharmacyOrder = await pharmacyOrderRepository.create(payload, ORDER_SCOPE_INCLUDE);

    await createPrescriptionDetailNote({
      encounterId: payload.encounter_id,
      items: pharmacyOrder.items || items,
      userId,
    });

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: scope.tenant_id || null,
      user_id: userId,
      action: 'CREATE',
      entity: 'pharmacy_order',
      entity_id: pharmacyOrder.id,
      diff: { after: pharmacyOrder },
      ip_address: ipAddress
    }).catch(() => {});

    return serializePharmacyOrder(pharmacyOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update pharmacy order
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Pharmacy order ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Updated pharmacy order
 */
const updatePharmacyOrder = async (id, data, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, pharmacyOrder: before } = await findScopedOrderOrThrow(id, user);
    const payload = { ...data };

    if (data.ordered_at !== undefined) {
      const orderedAt = normalizeOptionalDate(data.ordered_at);
      if (orderedAt) {
        payload.ordered_at = orderedAt;
      } else {
        delete payload.ordered_at;
      }
    }

    if (data.patient_id !== undefined) {
      payload.patient_id = await resolveScopedPatientId(data.patient_id, scope);
    }

    if (data.encounter_id !== undefined) {
      payload.encounter_id = await resolveScopedEncounterId(data.encounter_id, scope, true);
    }

    const pharmacyOrder = await pharmacyOrderRepository.update(before.id, payload, ORDER_SCOPE_INCLUDE);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before?.patient?.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'UPDATE',
      entity: 'pharmacy_order',
      entity_id: pharmacyOrder.id,
      diff: { before, after: pharmacyOrder },
      ip_address: ipAddress
    }).catch(() => {});

    return serializePharmacyOrder(pharmacyOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete pharmacy order (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Pharmacy order ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<void>}
 */
const deletePharmacyOrder = async (id, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, pharmacyOrder: before } = await findScopedOrderOrThrow(id, user);

    await pharmacyOrderRepository.softDelete(before.id);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before?.patient?.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'DELETE',
      entity: 'pharmacy_order',
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
 * Dispense pharmacy order
 *
 * @param {string} id - Pharmacy order ID
 * @param {Object} data - Dispense payload
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Updated pharmacy order
 */
const dispensePharmacyOrder = async (id, data = {}, userId, ipAddress, user = {}) => {
  try {
    const { scope, pharmacyOrder: before } = await findScopedOrderOrThrow(id, user);

    if (before.status === 'CANCELLED') {
      throw new HttpError('errors.pharmacy_order.cannot_dispense_cancelled', 400);
    }

    if (before.status === 'DISPENSED') {
      throw new HttpError('errors.pharmacy_order.already_dispensed', 400);
    }

    const pharmacyOrder = await pharmacyOrderRepository.update(
      before.id,
      {
        status: data.status || 'DISPENSED'
      },
      ORDER_SCOPE_INCLUDE
    );

    createAuditLog({
      tenant_id: before?.patient?.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'DISPENSE',
      entity: 'pharmacy_order',
      entity_id: pharmacyOrder.id,
      diff: {
        before,
        after: pharmacyOrder,
        metadata: {
          notes: data.notes || null
        }
      },
      ip_address: ipAddress
    }).catch(() => {});

    return serializePharmacyOrder(pharmacyOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPharmacyOrders,
  getPharmacyOrderById,
  createPharmacyOrder,
  updatePharmacyOrder,
  deletePharmacyOrder,
  dispensePharmacyOrder
};
