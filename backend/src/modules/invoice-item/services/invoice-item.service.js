/**
 * Invoice item service
 *
 * @module modules/invoice-item/services
 * @description Business logic layer for invoice item operations.
 */

const invoiceItemRepository = require('@repositories/invoice-item/invoice-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const INVOICE_TENANT_INCLUDE = {
  invoice: {
    select: {
      tenant_id: true
    }
  }
};

const resolveTenantId = (invoiceItem) => invoiceItem?.invoice?.tenant_id || null;

const buildEmptyListResult = (page, limit) => ({
  invoiceItems: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapInvoiceItemForDisplay = (record) => {
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
    timeline_at: record?.timeline_at || record?.created_at || null,
  };
};

/**
 * List invoice items
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @returns {Promise<Object>}
 */
const listInvoiceItems = async (filters, page, limit, sortBy, order) => {
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
    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { description: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }

    const [invoiceItems, total] = await Promise.all([
      invoiceItemRepository.findMany(whereClause, skip, limit, orderBy, {
        invoice: {
          select: {
            id: true,
            human_friendly_id: true,
            patient_id: true,
            patient: { select: { id: true, human_friendly_id: true } },
          },
        },
      }),
      invoiceItemRepository.count(whereClause)
    ]);

    return {
      invoiceItems: invoiceItems.map(mapInvoiceItemForDisplay),
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
 * Get invoice item by ID
 *
 * @param {string} id - Invoice item ID
 * @returns {Promise<Object>}
 */
const getInvoiceItemById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'invoice_item',
      identifier: id,
    });
    const invoiceItem = await invoiceItemRepository.findById(resolvedId, {
      invoice: {
        select: {
          id: true,
          human_friendly_id: true,
          patient_id: true,
          patient: { select: { id: true, human_friendly_id: true } },
        },
      },
    });

    if (!invoiceItem) {
      throw new HttpError('errors.invoice_item.not_found', 404);
    }

    return mapInvoiceItemForDisplay(invoiceItem);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create invoice item
 *
 * @param {Object} data - Invoice item data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const createInvoiceItem = async (data, userId, ipAddress) => {
  try {
    const invoiceId = await resolveIdentifierForPayload({
      value: data?.invoice_id,
      field: 'invoice_id',
      model: 'invoice',
    });
    const invoiceItem = await invoiceItemRepository.create({
      ...data,
      invoice_id: invoiceId,
    });
    const createdWithInvoice = await invoiceItemRepository.findById(invoiceItem.id, INVOICE_TENANT_INCLUDE);
    const tenantId = resolveTenantId(createdWithInvoice);
    const createdRecord = await invoiceItemRepository.findById(invoiceItem.id, {
      invoice: {
        select: {
          id: true,
          human_friendly_id: true,
          patient_id: true,
          patient: { select: { id: true, human_friendly_id: true } },
        },
      },
    });

    createAuditLog({
      tenant_id: tenantId,
      user_id: userId,
      action: 'CREATE',
      entity: 'invoice_item',
      entity_id: invoiceItem.id,
      diff: { after: invoiceItem },
      ip_address: ipAddress
    }).catch(() => {});

    return mapInvoiceItemForDisplay(createdRecord || invoiceItem);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update invoice item
 *
 * @param {string} id - Invoice item ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<Object>}
 */
const updateInvoiceItem = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'invoice_item',
      identifier: id,
    });
    const before = await invoiceItemRepository.findById(resolvedId, INVOICE_TENANT_INCLUDE);
    if (!before) {
      throw new HttpError('errors.invoice_item.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'invoice_id')) {
      payload.invoice_id = await resolveIdentifierForPayload({
        value: payload.invoice_id,
        field: 'invoice_id',
        model: 'invoice',
      });
    }

    const invoiceItem = await invoiceItemRepository.update(before.id, payload);
    const afterWithInvoice = await invoiceItemRepository.findById(before.id, INVOICE_TENANT_INCLUDE);
    const tenantId = resolveTenantId(afterWithInvoice) || resolveTenantId(before);
    const updatedRecord = await invoiceItemRepository.findById(invoiceItem.id, {
      invoice: {
        select: {
          id: true,
          human_friendly_id: true,
          patient_id: true,
          patient: { select: { id: true, human_friendly_id: true } },
        },
      },
    });

    createAuditLog({
      tenant_id: tenantId,
      user_id: userId,
      action: 'UPDATE',
      entity: 'invoice_item',
      entity_id: invoiceItem.id,
      diff: { before, after: invoiceItem },
      ip_address: ipAddress
    }).catch(() => {});

    return mapInvoiceItemForDisplay(updatedRecord || invoiceItem);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete invoice item (soft delete)
 *
 * @param {string} id - Invoice item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - Client IP address
 * @returns {Promise<void>}
 */
const deleteInvoiceItem = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'invoice_item',
      identifier: id,
    });
    const before = await invoiceItemRepository.findById(resolvedId, INVOICE_TENANT_INCLUDE);
    if (!before) {
      throw new HttpError('errors.invoice_item.not_found', 404);
    }

    await invoiceItemRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: resolveTenantId(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'invoice_item',
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
  listInvoiceItems,
  getInvoiceItemById,
  createInvoiceItem,
  updateInvoiceItem,
  deleteInvoiceItem
};
