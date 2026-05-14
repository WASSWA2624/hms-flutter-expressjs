/**
 * Billing Adjustment service
 *
 * @module modules/billing-adjustment/services
 * @description Business logic layer for billing adjustment operations.
 */

const billingAdjustmentRepository = require('@repositories/billing-adjustment/billing-adjustment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const ADJUSTMENT_INCLUDE = {
  invoice: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      patient_id: true,
      patient: { select: { id: true, human_friendly_id: true } },
    },
  },
};

const buildEmptyListResult = (page, limit) => ({
  billingAdjustments: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveTenantIdFromAdjustment = (record) => record?.invoice?.tenant_id || null;

const mapBillingAdjustmentForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    invoice_display_id: resolvePublicIdentifier(
      record?.invoice_display_id,
      record?.invoice?.human_friendly_id,
      record?.invoice_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.invoice?.patient?.human_friendly_id,
      record?.invoice?.patient_id
    ),
    timeline_at: record?.timeline_at || record?.adjusted_at || record?.created_at || null,
  };
};

/**
 * List billing adjustments with pagination and filtering
 */
const listBillingAdjustments = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.invoice_id !== undefined) {
      const invoiceId = await resolveIdentifierForFilter({
        value: filters.invoice_id,
        model: 'invoice',
      });
      if (invoiceId === null) return buildEmptyListResult(page, limit);
      if (invoiceId !== undefined) whereClause.invoice_id = invoiceId;
    }

    if (filters.status) whereClause.status = filters.status;

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { reason: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }

    const [billingAdjustments, total] = await Promise.all([
      billingAdjustmentRepository.findMany(whereClause, skip, limit, orderBy, ADJUSTMENT_INCLUDE),
      billingAdjustmentRepository.count(whereClause),
    ]);

    return {
      billingAdjustments: billingAdjustments.map(mapBillingAdjustmentForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get billing adjustment by ID
 */
const getBillingAdjustmentById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'billing_adjustment',
      identifier: id,
    });

    const billingAdjustment = await billingAdjustmentRepository.findById(resolvedId, ADJUSTMENT_INCLUDE);

    if (!billingAdjustment) {
      throw new HttpError('errors.billing_adjustment.not_found', 404);
    }

    return mapBillingAdjustmentForDisplay(billingAdjustment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new billing adjustment
 */
const createBillingAdjustment = async (data, userId, ipAddress) => {
  try {
    const invoiceId = await resolveIdentifierForPayload({
      value: data?.invoice_id,
      field: 'invoice_id',
      model: 'invoice',
    });

    const billingAdjustment = await billingAdjustmentRepository.create({
      ...data,
      invoice_id: invoiceId,
    });

    const createdRecord = await billingAdjustmentRepository.findById(
      billingAdjustment.id,
      ADJUSTMENT_INCLUDE
    );

    createAuditLog({
      tenant_id: resolveTenantIdFromAdjustment(createdRecord),
      user_id: userId,
      action: 'CREATE',
      entity: 'billing_adjustment',
      entity_id: billingAdjustment.id,
      diff: { after: billingAdjustment },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapBillingAdjustmentForDisplay(createdRecord || billingAdjustment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update billing adjustment
 */
const updateBillingAdjustment = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'billing_adjustment',
      identifier: id,
    });

    const before = await billingAdjustmentRepository.findById(resolvedId, ADJUSTMENT_INCLUDE);

    if (!before) {
      throw new HttpError('errors.billing_adjustment.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'invoice_id')) {
      payload.invoice_id = await resolveIdentifierForPayload({
        value: payload.invoice_id,
        field: 'invoice_id',
        model: 'invoice',
      });
    }

    const billingAdjustment = await billingAdjustmentRepository.update(before.id, payload);
    const updatedRecord = await billingAdjustmentRepository.findById(
      billingAdjustment.id,
      ADJUSTMENT_INCLUDE
    );

    createAuditLog({
      tenant_id: resolveTenantIdFromAdjustment(updatedRecord) || resolveTenantIdFromAdjustment(before),
      user_id: userId,
      action: 'UPDATE',
      entity: 'billing_adjustment',
      entity_id: billingAdjustment.id,
      diff: { before, after: billingAdjustment },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapBillingAdjustmentForDisplay(updatedRecord || billingAdjustment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete billing adjustment (soft delete)
 */
const deleteBillingAdjustment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'billing_adjustment',
      identifier: id,
    });

    const before = await billingAdjustmentRepository.findById(resolvedId, ADJUSTMENT_INCLUDE);

    if (!before) {
      throw new HttpError('errors.billing_adjustment.not_found', 404);
    }

    await billingAdjustmentRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: resolveTenantIdFromAdjustment(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'billing_adjustment',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listBillingAdjustments,
  getBillingAdjustmentById,
  createBillingAdjustment,
  updateBillingAdjustment,
  deleteBillingAdjustment,
};
