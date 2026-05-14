/**
 * Payment service
 *
 * @module modules/payment/services
 * @description Business logic layer for payment operations.
 */

const paymentRepository = require('@repositories/payment/payment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const buildEmptyListResult = (page, limit) => ({
  payments: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapPaymentForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  const mappedRefunds = Array.isArray(record.refunds)
    ? record.refunds.map((refund) => ({
        ...refund,
        display_id: resolvePublicIdentifier(refund?.display_id, refund?.human_friendly_id, refund?.id),
        payment_display_id: resolvePublicIdentifier(
          refund?.payment_display_id,
          record?.human_friendly_id,
          record?.id
        ),
      }))
    : record.refunds;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    facility_display_id: resolvePublicIdentifier(
      record?.facility_display_id,
      record?.facility?.human_friendly_id,
      record?.facility_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.patient?.human_friendly_id,
      record?.patient_id
    ),
    invoice_display_id: resolvePublicIdentifier(
      record?.invoice_display_id,
      record?.invoice?.human_friendly_id,
      record?.invoice_id
    ),
    timeline_at: record?.timeline_at || record?.paid_at || record?.created_at || null,
    refunds: mappedRefunds,
  };
};

const resolveListFilters = async (filters = {}, page, limit) => {
  const whereClause = {};

  if (filters.tenant_id !== undefined) {
    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
    });
    if (tenantId === null) return buildEmptyListResult(page, limit);
    if (tenantId !== undefined) whereClause.tenant_id = tenantId;
  }

  if (filters.facility_id !== undefined) {
    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
    });
    if (facilityId === null) return buildEmptyListResult(page, limit);
    if (facilityId !== undefined) whereClause.facility_id = facilityId;
  }

  if (filters.patient_id !== undefined) {
    const patientId = await resolveIdentifierForFilter({
      value: filters.patient_id,
      model: 'patient',
      where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
    });
    if (patientId === null) return buildEmptyListResult(page, limit);
    if (patientId !== undefined) whereClause.patient_id = patientId;
  }

  if (filters.invoice_id !== undefined) {
    const invoiceId = await resolveIdentifierForFilter({
      value: filters.invoice_id,
      model: 'invoice',
      where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
    });
    if (invoiceId === null) return buildEmptyListResult(page, limit);
    if (invoiceId !== undefined) whereClause.invoice_id = invoiceId;
  }

  if (filters.status) whereClause.status = filters.status;
  if (filters.method) whereClause.method = filters.method;

  if (filters.paid_at_from || filters.paid_at_to) {
    whereClause.paid_at = {};
    if (filters.paid_at_from) whereClause.paid_at.gte = new Date(filters.paid_at_from);
    if (filters.paid_at_to) whereClause.paid_at.lte = new Date(filters.paid_at_to);
  }

  const search = sanitizeIdentifier(filters.search);
  if (search) {
    whereClause.OR = [
      { transaction_ref: { contains: search } },
      { human_friendly_id: { contains: search.toUpperCase() } },
      { id: { contains: search } },
    ];
  }

  return whereClause;
};

/**
 * List payments
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @returns {Promise<Object>}
 */
const listPayments = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = await resolveListFilters(filters, page, limit);
    if (whereClause && whereClause.payments && whereClause.pagination) {
      return whereClause;
    }

    const [payments, total] = await Promise.all([
      paymentRepository.findMany(whereClause, skip, limit, orderBy, {
        tenant: { select: { id: true, human_friendly_id: true } },
        facility: { select: { id: true, human_friendly_id: true } },
        patient: { select: { id: true, human_friendly_id: true } },
        invoice: { select: { id: true, human_friendly_id: true } },
      }),
      paymentRepository.count(whereClause)
    ]);

    return {
      payments: payments.map(mapPaymentForDisplay),
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
 * Get payment by ID
 *
 * @param {string} id - Payment ID
 * @returns {Promise<Object>}
 */
const getPaymentById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payment',
      identifier: id,
    });
    const payment = await paymentRepository.findById(resolvedId, {
      tenant: true,
      facility: true,
      patient: true,
      invoice: true,
      refunds: true
    });

    if (!payment) {
      throw new HttpError('errors.payment.not_found', 404);
    }

    return mapPaymentForDisplay(payment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create payment
 *
 * @param {Object} data - Payment data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const createPayment = async (data, userId, ipAddress) => {
  try {
    const tenantId = await resolveIdentifierForPayload({
      value: data?.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
    });
    const facilityId = await resolveIdentifierForPayload({
      value: data?.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
    const patientId = await resolveIdentifierForPayload({
      value: data?.patient_id,
      field: 'patient_id',
      model: 'patient',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
    const invoiceId = await resolveIdentifierForPayload({
      value: data?.invoice_id,
      field: 'invoice_id',
      model: 'invoice',
      where: tenantId ? { tenant_id: tenantId } : {},
    });

    const payload = {
      ...data,
      tenant_id: tenantId,
      facility_id: facilityId,
      patient_id: patientId,
      invoice_id: invoiceId,
    };

    const payment = await paymentRepository.create(payload);
    const createdRecord = await paymentRepository.findById(payment.id, {
      tenant: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      patient: { select: { id: true, human_friendly_id: true } },
      invoice: { select: { id: true, human_friendly_id: true } },
    });

    createAuditLog({
      tenant_id: payment.tenant_id || tenantId,
      user_id: userId,
      action: 'CREATE',
      entity: 'payment',
      entity_id: payment.id,
      diff: { after: payment },
      ip_address: ipAddress
    }).catch(() => {});

    return mapPaymentForDisplay(createdRecord || payment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update payment
 *
 * @param {string} id - Payment ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const updatePayment = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payment',
      identifier: id,
    });
    const before = await paymentRepository.findById(resolvedId);
    if (!before) {
      throw new HttpError('errors.payment.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'facility_id')) {
      payload.facility_id = await resolveIdentifierForPayload({
        value: payload.facility_id,
        field: 'facility_id',
        model: 'facility',
        where: before.tenant_id ? { tenant_id: before.tenant_id } : {},
        nullable: true,
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'patient_id')) {
      payload.patient_id = await resolveIdentifierForPayload({
        value: payload.patient_id,
        field: 'patient_id',
        model: 'patient',
        where: before.tenant_id ? { tenant_id: before.tenant_id } : {},
        nullable: true,
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'invoice_id')) {
      payload.invoice_id = await resolveIdentifierForPayload({
        value: payload.invoice_id,
        field: 'invoice_id',
        model: 'invoice',
        where: before.tenant_id ? { tenant_id: before.tenant_id } : {},
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id')) {
      payload.tenant_id = await resolveIdentifierForPayload({
        value: payload.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
      });
    }

    const payment = await paymentRepository.update(before.id, payload);
    const updatedRecord = await paymentRepository.findById(payment.id, {
      tenant: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      patient: { select: { id: true, human_friendly_id: true } },
      invoice: { select: { id: true, human_friendly_id: true } },
    });
    const tenantId = payment.tenant_id || before.tenant_id;

    createAuditLog({
      tenant_id: tenantId,
      user_id: userId,
      action: 'UPDATE',
      entity: 'payment',
      entity_id: payment.id,
      diff: { before, after: payment },
      ip_address: ipAddress
    }).catch(() => {});

    return mapPaymentForDisplay(updatedRecord || payment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete payment (soft delete)
 *
 * @param {string} id - Payment ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<void>}
 */
const deletePayment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payment',
      identifier: id,
    });
    const before = await paymentRepository.findById(resolvedId);
    if (!before) {
      throw new HttpError('errors.payment.not_found', 404);
    }

    await paymentRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'payment',
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
 * Reconcile payment
 *
 * @param {string} id - Payment ID
 * @param {Object} data - Reconciliation payload
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const reconcilePayment = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payment',
      identifier: id,
    });
    const before = await paymentRepository.findById(resolvedId);
    if (!before) {
      throw new HttpError('errors.payment.not_found', 404);
    }

    const payment = await paymentRepository.update(before.id, {
      status: data.status || 'COMPLETED',
      paid_at: before.paid_at || new Date()
    });
    const updatedRecord = await paymentRepository.findById(payment.id, {
      tenant: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      patient: { select: { id: true, human_friendly_id: true } },
      invoice: { select: { id: true, human_friendly_id: true } },
    });

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'RECONCILE',
      entity: 'payment',
      entity_id: payment.id,
      diff: {
        before,
        after: payment,
        metadata: {
          notes: data.notes || null
        }
      },
      ip_address: ipAddress
    }).catch(() => {});

    return mapPaymentForDisplay(updatedRecord || payment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get payment channel breakdown for the payment tenant
 *
 * @param {string} id - Payment ID
 * @returns {Promise<Object>}
 */
const getPaymentChannelBreakdown = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payment',
      identifier: id,
    });
    const payment = await paymentRepository.findById(resolvedId);
    if (!payment) {
      throw new HttpError('errors.payment.not_found', 404);
    }

    const tenantPayments = await paymentRepository.findMany(
      { tenant_id: payment.tenant_id },
      0,
      1000,
      { created_at: 'desc' }
    );

    const channelBreakdown = tenantPayments.reduce((acc, item) => {
      const method = item.method || 'OTHER';
      const amount = Number(item.amount || 0);
      if (!acc[method]) {
        acc[method] = { count: 0, amount: 0 };
      }
      acc[method].count += 1;
      acc[method].amount = Math.round((acc[method].amount + amount) * 100) / 100;
      return acc;
    }, {});

    return {
      tenant_id: payment.tenant_id,
      total_payments: tenantPayments.length,
      channel_breakdown: channelBreakdown
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPayments,
  getPaymentById,
  createPayment,
  updatePayment,
  deletePayment,
  reconcilePayment,
  getPaymentChannelBreakdown
};
