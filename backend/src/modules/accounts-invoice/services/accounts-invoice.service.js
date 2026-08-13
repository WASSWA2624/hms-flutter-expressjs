/**
 * Accounts Invoice service — facility outflow invoices.
 */

const accountsInvoiceRepository = require('@repositories/accounts-invoice/accounts-invoice.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolvePublicIdentifier,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');
const { randomUUID } = require('crypto');

const INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  items: {
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
  },
};

const toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'object' && typeof value.toNumber === 'function') {
    return value.toNumber();
  }
  return Number(value);
};

const mapItem = (item) => ({
  id: item.id,
  display_id: resolvePublicIdentifier(
    item.display_id,
    item.human_friendly_id,
    item.id
  ),
  name: item.name,
  description: item.description,
  quantity: toNumber(item.quantity),
  unit_price: toNumber(item.unit_price),
  line_total: toNumber(item.line_total),
});

const mapInvoice = (record) => {
  if (!record || typeof record !== 'object') return record;
  return {
    ...record,
    display_id: resolvePublicIdentifier(
      record.display_id,
      record.human_friendly_id,
      record.id
    ),
    total_amount: toNumber(record.total_amount),
    tenant_display_id: resolvePublicIdentifier(
      record.tenant_display_id,
      record.tenant?.human_friendly_id,
      record.tenant_id
    ),
    facility_display_id: resolvePublicIdentifier(
      record.facility_display_id,
      record.facility?.human_friendly_id,
      record.facility_id
    ),
    items: Array.isArray(record.items) ? record.items.map(mapItem) : [],
  };
};

const normalizeItems = (items = []) => {
  const normalized = items.map((item) => {
    const quantity = Number(item.quantity);
    const unitPrice = Number(item.unit_price);
    if (!(quantity > 0) || !(unitPrice >= 0) || !Number.isFinite(quantity) || !Number.isFinite(unitPrice)) {
      throw new HttpError('errors.validation.invalid', 400, [
        { field: 'items' },
      ]);
    }
    const lineTotal = Math.round(quantity * unitPrice * 100) / 100;
    return {
      id: randomUUID(),
      name: String(item.name || '').trim(),
      description: item.description ? String(item.description).trim() : null,
      quantity,
      unit_price: unitPrice,
      line_total: lineTotal,
    };
  });
  if (normalized.some((row) => !row.name)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'items.name' }]);
  }
  return normalized;
};

const sumItems = (items) =>
  Math.round(items.reduce((sum, row) => sum + Number(row.line_total), 0) * 100) /
  100;

const parseDate = (value) => {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'invoice_date' }]);
  }
  return date;
};

const listAccountsInvoices = async (filters, page, limit) => {
  const where = {};
  if (filters.tenant_id) {
    where.tenant_id = await resolveIdentifierForPayload({
      value: filters.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
    });
  }
  if (filters.facility_id) {
    where.facility_id = await resolveIdentifierForPayload({
      value: filters.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true,
    });
  }
  if (filters.status) where.status = filters.status;
  if (filters.date_from || filters.date_to) {
    where.invoice_date = {};
    if (filters.date_from) where.invoice_date.gte = parseDate(filters.date_from);
    if (filters.date_to) where.invoice_date.lte = parseDate(filters.date_to);
  }
  const search = (filters.search || '').trim();
  if (search) {
    where.OR = [
      { payee: { contains: search } },
      { reference: { contains: search } },
      { human_friendly_id: { contains: search.toUpperCase() } },
      { status: { equals: search.toUpperCase() } },
    ];
  }

  const skip = (page - 1) * limit;
  const [rows, total] = await Promise.all([
    accountsInvoiceRepository.findMany(where, skip, limit, { invoice_date: 'desc' }, INCLUDE),
    accountsInvoiceRepository.count(where),
  ]);

  return {
    accountsInvoices: rows.map(mapInvoice),
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 0,
      hasNextPage: page < Math.ceil(total / limit),
      hasPreviousPage: page > 1,
    },
  };
};

const getAccountsInvoiceById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'accounts_invoice',
    identifier: id,
  });
  const record = await accountsInvoiceRepository.findById(resolvedId, INCLUDE);
  if (!record) throw new HttpError('errors.accounts_invoice.not_found', 404);
  return mapInvoice(record);
};

const createAccountsInvoice = async (data, userId, ipAddress) => {
  const items = normalizeItems(data.items);
  const payload = {
    id: randomUUID(),
    tenant_id: await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
    }),
    facility_id: await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true,
    }),
    payee: String(data.payee).trim(),
    invoice_date: parseDate(data.invoice_date),
    reference: data.reference ? String(data.reference).trim() : null,
    notes: data.notes ? String(data.notes).trim() : null,
    currency: (data.currency || 'UGX').toUpperCase(),
    status: data.status === 'ISSUED' ? 'ISSUED' : 'DRAFT',
    total_amount: sumItems(items),
    items: {
      create: items.map((item) => ({
        id: item.id,
        name: item.name,
        description: item.description,
        quantity: item.quantity,
        unit_price: item.unit_price,
        line_total: item.line_total,
      })),
    },
  };

  const created = await accountsInvoiceRepository.create(payload);
  const full = await accountsInvoiceRepository.findById(created.id, INCLUDE);

  createAuditLog({
    tenant_id: created.tenant_id,
    user_id: userId,
    action: 'CREATE',
    entity: 'accounts_invoice',
    entity_id: created.id,
    diff: { after: created },
    ip_address: ipAddress,
  }).catch(() => {});

  return mapInvoice(full || created);
};

const updateAccountsInvoice = async (id, data, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'accounts_invoice',
    identifier: id,
  });
  const before = await accountsInvoiceRepository.findById(resolvedId, INCLUDE);
  if (!before) throw new HttpError('errors.accounts_invoice.not_found', 404);
  if (before.status === 'VOIDED') {
    throw new HttpError('errors.accounts_invoice.voided', 409);
  }

  const payload = {};
  if (data.payee != null) payload.payee = String(data.payee).trim();
  if (data.invoice_date != null) payload.invoice_date = parseDate(data.invoice_date);
  if (Object.prototype.hasOwnProperty.call(data, 'reference')) {
    payload.reference = data.reference ? String(data.reference).trim() : null;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'notes')) {
    payload.notes = data.notes ? String(data.notes).trim() : null;
  }
  if (data.currency != null) payload.currency = String(data.currency).toUpperCase();
  if (data.status === 'DRAFT' || data.status === 'ISSUED') payload.status = data.status;

  if (Array.isArray(data.items)) {
    const items = normalizeItems(data.items);
    payload.total_amount = sumItems(items);
    await accountsInvoiceRepository.deleteItemsForInvoice(before.id);
    await accountsInvoiceRepository.createItems(
      items.map((item) => ({
        id: item.id,
        accounts_invoice_id: before.id,
        name: item.name,
        description: item.description,
        quantity: item.quantity,
        unit_price: item.unit_price,
        line_total: item.line_total,
      }))
    );
  }

  const updated = await accountsInvoiceRepository.update(before.id, payload);
  const full = await accountsInvoiceRepository.findById(updated.id, INCLUDE);

  createAuditLog({
    tenant_id: updated.tenant_id || before.tenant_id,
    user_id: userId,
    action: 'UPDATE',
    entity: 'accounts_invoice',
    entity_id: updated.id,
    diff: { before, after: updated },
    ip_address: ipAddress,
  }).catch(() => {});

  return mapInvoice(full || updated);
};

const voidAccountsInvoice = async (id, body, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'accounts_invoice',
    identifier: id,
  });
  const before = await accountsInvoiceRepository.findById(resolvedId, INCLUDE);
  if (!before) throw new HttpError('errors.accounts_invoice.not_found', 404);
  if (before.status === 'VOIDED') {
    throw new HttpError('errors.accounts_invoice.voided', 409);
  }

  const reason = String(body.reason || '').trim();
  if (!reason) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'reason' }]);
  }

  const notes = body.notes ? String(body.notes).trim() : null;
  const updated = await accountsInvoiceRepository.update(before.id, {
    status: 'VOIDED',
    void_reason: reason,
    voided_at: new Date(),
    notes: notes || before.notes,
  });
  const full = await accountsInvoiceRepository.findById(updated.id, INCLUDE);

  createAuditLog({
    tenant_id: updated.tenant_id || before.tenant_id,
    user_id: userId,
    action: 'VOID',
    entity: 'accounts_invoice',
    entity_id: updated.id,
    diff: { before, after: updated, reason },
    ip_address: ipAddress,
  }).catch(() => {});

  return mapInvoice(full || updated);
};

const countActiveInvoices = async (filters = {}) => {
  const where = { status: { not: 'VOIDED' } };
  if (filters.tenant_id) {
    where.tenant_id = await resolveIdentifierForPayload({
      value: filters.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
    });
  }
  if (filters.facility_id) {
    where.facility_id = await resolveIdentifierForPayload({
      value: filters.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true,
    });
  }
  return accountsInvoiceRepository.count(where);
};

module.exports = {
  listAccountsInvoices,
  getAccountsInvoiceById,
  createAccountsInvoice,
  updateAccountsInvoice,
  voidAccountsInvoice,
  countActiveInvoices,
};
