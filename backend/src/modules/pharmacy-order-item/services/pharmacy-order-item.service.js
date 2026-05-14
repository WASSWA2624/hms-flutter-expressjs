/**
 * Pharmacy order item service
 *
 * @module modules/pharmacy-order-item/services
 * @description Business logic layer for pharmacy order item operations.
 */

const pharmacyOrderItemRepository = require('@repositories/pharmacy-order-item/pharmacy-order-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdOrThrow,
  resolveScopedUserContext,
  buildDrugScopeWhere,
  buildOrderItemScopeWhere,
  buildOrderScopeWhere,
  matchesOrderItemScope,
} = require('@services/pharmacy-workspace/pharmacy.shared');

const ORDER_TENANT_INCLUDE = {
  pharmacy_order: {
    select: {
      patient: {
        select: {
          tenant_id: true,
          facility_id: true,
        }
      }
    }
  }
};

const resolveTenantId = (pharmacyOrderItem) => pharmacyOrderItem?.pharmacy_order?.patient?.tenant_id || null;

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

const buildDosageText = (data = {}) => {
  const explicitDosage = sanitizeString(data.dosage);
  if (explicitDosage) return explicitDosage;

  const doseAmount = normalizePositiveNumber(data.dose_amount);
  const doseUnit = sanitizeString(data.dose_unit);
  if (!doseAmount || !doseUnit) return null;

  return `${doseAmount} ${doseUnit}`;
};

const normalizeItemPayload = (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(payload, 'dosage') ||
      Object.prototype.hasOwnProperty.call(payload, 'dose_amount') ||
      Object.prototype.hasOwnProperty.call(payload, 'dose_unit')) {
    payload.dosage = buildDosageText(payload);
  }

  [
    'quantity_unit',
    'dose_unit',
    'duration_unit',
    'instructions',
    'custom_prescription',
  ].forEach((field) => {
    if (Object.prototype.hasOwnProperty.call(payload, field)) {
      payload[field] = normalizeNullableString(payload[field]);
    }
  });

  if (Object.prototype.hasOwnProperty.call(payload, 'dose_amount')) {
    payload.dose_amount = normalizePositiveNumber(payload.dose_amount);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'duration_value')) {
    payload.duration_value = payload.duration_value
      ? Number(payload.duration_value)
      : null;
  }

  return payload;
};

const resolveScopedOrderId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'pharmacy_order',
    where: {
      deleted_at: null,
      ...buildOrderScopeWhere(scope),
    },
    errorKey: 'errors.pharmacy_order.not_found',
    allowNull,
  });

const resolveScopedDrugId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'drug',
    where: {
      deleted_at: null,
      ...buildDrugScopeWhere(scope),
    },
    errorKey: 'errors.drug.not_found',
    allowNull,
  });

const findScopedOrderItemOrThrow = async (id, include = ORDER_TENANT_INCLUDE, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const pharmacyOrderItem = await pharmacyOrderItemRepository.findById(id, include);

  if (!pharmacyOrderItem || !matchesOrderItemScope(pharmacyOrderItem, scope)) {
    throw new HttpError('errors.pharmacy_order_item.not_found', 404);
  }

  return { scope, pharmacyOrderItem };
};

/**
 * List pharmacy order items
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>}
 */
const listPharmacyOrderItems = async (filters, page, limit, sortBy, order, userId, ipAddress, user = {}) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const scope = resolveScopedUserContext(user);

    const whereClause = {
      ...buildOrderItemScopeWhere(scope),
    };
    if (filters.pharmacy_order_id) {
      whereClause.pharmacy_order_id = await resolveScopedOrderId(filters.pharmacy_order_id, scope);
    }
    if (filters.drug_id) {
      whereClause.drug_id = await resolveScopedDrugId(filters.drug_id, scope);
    }
    if (filters.status) whereClause.status = filters.status;
    if (filters.route) whereClause.route = filters.route;
    if (filters.frequency) whereClause.frequency = filters.frequency;

    if (filters.search) {
      whereClause.OR = [
        { dosage: { contains: filters.search } },
        { id: { contains: filters.search } }
      ];
    }

    const [pharmacyOrderItems, total] = await Promise.all([
      pharmacyOrderItemRepository.findMany(whereClause, skip, limit, orderBy),
      pharmacyOrderItemRepository.count(whereClause)
    ]);

    return {
      pharmacyOrderItems,
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
 * Get pharmacy order item by ID
 *
 * @param {string} id - Pharmacy order item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>}
 */
const getPharmacyOrderItemById = async (id, userId, ipAddress, user = {}) => {
  try {
    const { pharmacyOrderItem } = await findScopedOrderItemOrThrow(
      id,
      {
        pharmacy_order: {
          include: {
            patient: {
              select: {
                tenant_id: true,
                facility_id: true,
              },
            },
          },
        },
        drug: true,
        dispense_logs: true,
      },
      user
    );

    if (!pharmacyOrderItem) {
      throw new HttpError('errors.pharmacy_order_item.not_found', 404);
    }

    return pharmacyOrderItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create pharmacy order item
 *
 * @param {Object} data - Pharmacy order item data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>}
 */
const createPharmacyOrderItem = async (data, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const payload = normalizeItemPayload({
      ...data,
      pharmacy_order_id: await resolveScopedOrderId(data.pharmacy_order_id, scope),
      drug_id: await resolveScopedDrugId(data.drug_id, scope),
    });

    const pharmacyOrderItem = await pharmacyOrderItemRepository.create(payload);
    const createdWithOrder = await pharmacyOrderItemRepository.findById(pharmacyOrderItem.id, ORDER_TENANT_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantId(createdWithOrder),
      user_id: userId,
      action: 'CREATE',
      entity: 'pharmacy_order_item',
      entity_id: pharmacyOrderItem.id,
      diff: { after: pharmacyOrderItem },
      ip_address: ipAddress
    }).catch(() => {});

    return pharmacyOrderItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update pharmacy order item
 *
 * @param {string} id - Pharmacy order item ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>}
 */
const updatePharmacyOrderItem = async (id, data, userId, ipAddress, user = {}) => {
  try {
    const { scope, pharmacyOrderItem: before } = await findScopedOrderItemOrThrow(
      id,
      ORDER_TENANT_INCLUDE,
      user
    );
    const payload = normalizeItemPayload(data);

    if (data.pharmacy_order_id !== undefined) {
      payload.pharmacy_order_id = await resolveScopedOrderId(data.pharmacy_order_id, scope);
    }

    if (data.drug_id !== undefined) {
      payload.drug_id = await resolveScopedDrugId(data.drug_id, scope);
    }

    const pharmacyOrderItem = await pharmacyOrderItemRepository.update(id, payload);
    const afterWithOrder = await pharmacyOrderItemRepository.findById(id, ORDER_TENANT_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantId(afterWithOrder) || resolveTenantId(before),
      user_id: userId,
      action: 'UPDATE',
      entity: 'pharmacy_order_item',
      entity_id: pharmacyOrderItem.id,
      diff: { before, after: pharmacyOrderItem },
      ip_address: ipAddress
    }).catch(() => {});

    return pharmacyOrderItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete pharmacy order item (soft delete)
 *
 * @param {string} id - Pharmacy order item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<void>}
 */
const deletePharmacyOrderItem = async (id, userId, ipAddress, user = {}) => {
  try {
    const { pharmacyOrderItem: before } = await findScopedOrderItemOrThrow(id, ORDER_TENANT_INCLUDE, user);

    await pharmacyOrderItemRepository.softDelete(id);

    createAuditLog({
      tenant_id: resolveTenantId(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'pharmacy_order_item',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPharmacyOrderItems,
  getPharmacyOrderItemById,
  createPharmacyOrderItem,
  updatePharmacyOrderItem,
  deletePharmacyOrderItem
};
