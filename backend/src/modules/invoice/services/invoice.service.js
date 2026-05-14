/**
 * Invoice service
 *
 * @module modules/invoice/services
 * @description Business logic layer for invoice operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const invoiceRepository = require('@repositories/invoice/invoice.repository');
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
  invoices: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapInvoiceForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  const mappedItems = Array.isArray(record.items)
    ? record.items.map((item) => ({
        ...item,
        display_id: resolvePublicIdentifier(item?.display_id, item?.human_friendly_id, item?.id),
        invoice_display_id: resolvePublicIdentifier(
          item?.invoice_display_id,
          record?.human_friendly_id,
          record?.id
        ),
      }))
    : record.items;

  const mappedPayments = Array.isArray(record.payments)
    ? record.payments.map((payment) => ({
        ...payment,
        display_id: resolvePublicIdentifier(payment?.display_id, payment?.human_friendly_id, payment?.id),
        invoice_display_id: resolvePublicIdentifier(
          payment?.invoice_display_id,
          record?.human_friendly_id,
          record?.id
        ),
      }))
    : record.payments;

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
    timeline_at: record?.timeline_at || record?.issued_at || record?.created_at || null,
    items: mappedItems,
    payments: mappedPayments,
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

  if (filters.status) whereClause.status = filters.status;
  if (filters.billing_status) whereClause.billing_status = filters.billing_status;

  const search = sanitizeIdentifier(filters.search);
  if (search) {
    whereClause.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { id: { contains: search } },
    ];
  }

  return whereClause;
};

/**
 * List invoices with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Invoices and pagination data
 */
const listInvoices = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = await resolveListFilters(filters, page, limit);
    if (whereClause && whereClause.invoices && whereClause.pagination) {
      return whereClause;
    }

    const [invoices, total] = await Promise.all([
      invoiceRepository.findMany(whereClause, skip, limit, orderBy, {
        tenant: { select: { id: true, human_friendly_id: true } },
        facility: { select: { id: true, human_friendly_id: true } },
        patient: { select: { id: true, human_friendly_id: true } },
      }),
      invoiceRepository.count(whereClause)
    ]);

    return {
      invoices: invoices.map(mapInvoiceForDisplay),
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
 * Get invoice by ID
 *
 * @param {string} id - Invoice ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Invoice data
 */
const getInvoiceById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'invoice',
      identifier: id,
    });
    const invoice = await invoiceRepository.findById(resolvedId, {
      items: true,
      payments: true,
      tenant: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      patient: { select: { id: true, human_friendly_id: true } }
    });

    if (!invoice) {
      throw new HttpError('errors.invoice.not_found', 404);
    }

    return mapInvoiceForDisplay(invoice);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new invoice
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Invoice data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created invoice
 */
const createInvoice = async (data, userId, ipAddress) => {
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

    const payload = {
      ...data,
      tenant_id: tenantId,
      facility_id: facilityId,
      patient_id: patientId,
    };

    const invoice = await invoiceRepository.create(payload);
    const createdRecord = await invoiceRepository.findById(invoice.id, {
      tenant: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      patient: { select: { id: true, human_friendly_id: true } },
    });

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: invoice.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'invoice',
      entity_id: invoice.id,
      diff: { after: invoice },
      ip_address: ipAddress
    }).catch(() => {});

    return mapInvoiceForDisplay(createdRecord || invoice);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update invoice
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Invoice ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated invoice
 */
const updateInvoice = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'invoice',
      identifier: id,
    });
    // Get current state for audit
    const before = await invoiceRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.invoice.not_found', 404);
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

    const invoice = await invoiceRepository.update(before.id, payload);
    const updatedRecord = await invoiceRepository.findById(invoice.id, {
      tenant: { select: { id: true, human_friendly_id: true } },
      facility: { select: { id: true, human_friendly_id: true } },
      patient: { select: { id: true, human_friendly_id: true } },
    });

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: invoice.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'invoice',
      entity_id: invoice.id,
      diff: { before, after: invoice },
      ip_address: ipAddress
    }).catch(() => {});

    return mapInvoiceForDisplay(updatedRecord || invoice);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete invoice (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Invoice ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteInvoice = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'invoice',
      identifier: id,
    });
    // Get current state for audit
    const before = await invoiceRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.invoice.not_found', 404);
    }

    await invoiceRepository.softDelete(before.id);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'invoice',
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
  listInvoices,
  getInvoiceById,
  createInvoice,
  updateInvoice,
  deleteInvoice
};
