/**
 * Refund service
 *
 * @module modules/refund/services
 * @description Business logic layer for refund operations.
 */

const refundRepository = require('@repositories/refund/refund.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const PAYMENT_TENANT_INCLUDE = {
  payment: {
    select: {
      tenant_id: true
    }
  }
};

const resolveTenantId = (refund) => refund?.payment?.tenant_id || null;

const buildEmptyListResult = (page, limit) => ({
  refunds: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapRefundForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    payment_display_id: resolvePublicIdentifier(
      record?.payment_display_id,
      record?.payment?.human_friendly_id,
      record?.payment_id
    ),
    invoice_display_id: resolvePublicIdentifier(
      record?.invoice_display_id,
      record?.payment?.invoice?.human_friendly_id,
      record?.payment?.invoice_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.payment?.patient?.human_friendly_id,
      record?.payment?.patient_id
    ),
    timeline_at: record?.timeline_at || record?.refunded_at || record?.created_at || null,
  };
};

/**
 * List refunds
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @returns {Promise<Object>}
 */
const listRefunds = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { refunded_at: 'desc' };

    const whereClause = {};
    if (filters.payment_id !== undefined) {
      const paymentId = await resolveIdentifierForFilter({
        value: filters.payment_id,
        model: 'payment',
      });
      if (paymentId === null) return buildEmptyListResult(page, limit);
      if (paymentId !== undefined) whereClause.payment_id = paymentId;
    }

    if (filters.refunded_at_from || filters.refunded_at_to) {
      whereClause.refunded_at = {};
      if (filters.refunded_at_from) whereClause.refunded_at.gte = new Date(filters.refunded_at_from);
      if (filters.refunded_at_to) whereClause.refunded_at.lte = new Date(filters.refunded_at_to);
    }

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { reason: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
        { id: { contains: search } }
      ];
    }

    const [refunds, total] = await Promise.all([
      refundRepository.findMany(whereClause, skip, limit, orderBy, {
        payment: {
          select: {
            id: true,
            human_friendly_id: true,
            patient_id: true,
            tenant_id: true,
            invoice_id: true,
            patient: { select: { id: true, human_friendly_id: true } },
            invoice: { select: { id: true, human_friendly_id: true } },
          },
        },
      }),
      refundRepository.count(whereClause)
    ]);

    return {
      refunds: refunds.map(mapRefundForDisplay),
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
 * Get refund by ID
 *
 * @param {string} id - Refund ID
 * @returns {Promise<Object>}
 */
const getRefundById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'refund',
      identifier: id,
    });
    const refund = await refundRepository.findById(resolvedId, {
      payment: {
        select: {
          id: true,
          human_friendly_id: true,
          patient_id: true,
          tenant_id: true,
          invoice_id: true,
          patient: { select: { id: true, human_friendly_id: true } },
          invoice: { select: { id: true, human_friendly_id: true } },
        },
      },
    });

    if (!refund) {
      throw new HttpError('errors.refund.not_found', 404);
    }

    return mapRefundForDisplay(refund);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create refund
 *
 * @param {Object} data - Refund data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const createRefund = async (data, userId, ipAddress) => {
  try {
    const paymentId = await resolveIdentifierForPayload({
      value: data?.payment_id,
      field: 'payment_id',
      model: 'payment',
    });

    const refund = await refundRepository.create({
      ...data,
      payment_id: paymentId,
    });
    const createdWithPayment = await refundRepository.findById(refund.id, PAYMENT_TENANT_INCLUDE);
    const tenantId = resolveTenantId(createdWithPayment);
    const createdRecord = await refundRepository.findById(refund.id, {
      payment: {
        select: {
          id: true,
          human_friendly_id: true,
          patient_id: true,
          tenant_id: true,
          invoice_id: true,
          patient: { select: { id: true, human_friendly_id: true } },
          invoice: { select: { id: true, human_friendly_id: true } },
        },
      },
    });

    createAuditLog({
      tenant_id: tenantId,
      user_id: userId,
      action: 'CREATE',
      entity: 'refund',
      entity_id: refund.id,
      diff: { after: refund },
      ip_address: ipAddress
    }).catch(() => {});

    return mapRefundForDisplay(createdRecord || refund);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update refund
 *
 * @param {string} id - Refund ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const updateRefund = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'refund',
      identifier: id,
    });
    const before = await refundRepository.findById(resolvedId, PAYMENT_TENANT_INCLUDE);
    if (!before) {
      throw new HttpError('errors.refund.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'payment_id')) {
      payload.payment_id = await resolveIdentifierForPayload({
        value: payload.payment_id,
        field: 'payment_id',
        model: 'payment',
      });
    }

    const refund = await refundRepository.update(before.id, payload);
    const afterWithPayment = await refundRepository.findById(before.id, PAYMENT_TENANT_INCLUDE);
    const tenantId = resolveTenantId(afterWithPayment) || resolveTenantId(before);
    const updatedRecord = await refundRepository.findById(refund.id, {
      payment: {
        select: {
          id: true,
          human_friendly_id: true,
          patient_id: true,
          tenant_id: true,
          invoice_id: true,
          patient: { select: { id: true, human_friendly_id: true } },
          invoice: { select: { id: true, human_friendly_id: true } },
        },
      },
    });

    createAuditLog({
      tenant_id: tenantId,
      user_id: userId,
      action: 'UPDATE',
      entity: 'refund',
      entity_id: refund.id,
      diff: { before, after: refund },
      ip_address: ipAddress
    }).catch(() => {});

    return mapRefundForDisplay(updatedRecord || refund);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete refund (soft delete)
 *
 * @param {string} id - Refund ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<void>}
 */
const deleteRefund = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'refund',
      identifier: id,
    });
    const before = await refundRepository.findById(resolvedId, PAYMENT_TENANT_INCLUDE);
    if (!before) {
      throw new HttpError('errors.refund.not_found', 404);
    }

    await refundRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: resolveTenantId(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'refund',
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
  listRefunds,
  getRefundById,
  createRefund,
  updateRefund,
  deleteRefund
};
