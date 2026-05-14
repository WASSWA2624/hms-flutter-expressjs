/**
 * Subscription Invoice service
 *
 * @module modules/subscription-invoice/services
 * @description Business logic layer for subscription invoice operations.
 */

const subscriptionInvoiceRepository = require('@repositories/subscription-invoice/subscription-invoice.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');
const {
  serializeSubscriptionInvoice,
  serializeSubscriptionInvoiceCollection,
} = require('@lib/subscriptions/serializers');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const {
  canAccessTenant,
  resolveUserTenantScope,
} = require('@lib/subscriptions/access');

const INVOICE_INCLUDE = Object.freeze({
  subscription: {
    include: {
      tenant: true,
      plan: true,
    },
  },
  invoice: true,
});

const requireTenantScope = (user = {}) => {
  const scope = resolveUserTenantScope(user);
  if (!scope.is_elevated && !scope.tenant_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return scope;
};

const emptyList = (page, limit) => ({
  subscriptionInvoices: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const loadSubscriptionInvoiceRecord = async (identifier, user = {}) => {
  const scope = requireTenantScope(user);
  const resolvedId = await resolveEntityId({
    model: 'subscription_invoice',
    identifier,
  });
  const record = await subscriptionInvoiceRepository.findById(resolvedId, INVOICE_INCLUDE);

  if (
    !record
    || !canAccessTenant(scope, record.subscription?.tenant_id)
  ) {
    throw new HttpError('errors.subscription_invoice.not_found', 404);
  }

  return record;
};

const resolveSubscriptionInvoicePayload = async (
  data = {},
  user = {},
  tenantIdContext = null
) => {
  const scope = requireTenantScope(user);
  const scopedTenantId = scope.is_elevated
    ? tenantIdContext || null
    : scope.tenant_id;

  const payload = {
    ...data,
  };

  if (data.subscription_id !== undefined) {
    payload.subscription_id = await resolveIdentifierForPayload({
      value: data.subscription_id,
      model: 'subscription',
      field: 'subscription_id',
      where: scopedTenantId ? { tenant_id: scopedTenantId } : {},
    });
  }

  if (data.invoice_id !== undefined) {
    payload.invoice_id = await resolveIdentifierForPayload({
      value: data.invoice_id,
      model: 'invoice',
      field: 'invoice_id',
      where: scopedTenantId ? { tenant_id: scopedTenantId } : {},
    });
  }

  return payload;
};

const getSubscriptionInvoiceById = async (id, user = {}) => {
  const record = await loadSubscriptionInvoiceRecord(id, user);
  return serializeSubscriptionInvoice(record);
};

const listSubscriptionInvoices = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'created_at',
  order = 'desc',
  user = {}
) => {
  const scope = requireTenantScope(user);
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };
  const where = !scope.is_elevated
    ? { subscription: { tenant_id: scope.tenant_id } }
    : {};

  if (filters.subscription_id) {
    const subscriptionId = await resolveIdentifierForFilter({
      value: filters.subscription_id,
      model: 'subscription',
      where: !scope.is_elevated ? { tenant_id: scope.tenant_id } : {},
    });
    if (subscriptionId === null) return emptyList(page, limit);
    if (subscriptionId) {
      where.subscription_id = subscriptionId;
    }
  }

  if (filters.invoice_id) {
    const invoiceId = await resolveIdentifierForFilter({
      value: filters.invoice_id,
      model: 'invoice',
      where: !scope.is_elevated ? { tenant_id: scope.tenant_id } : {},
    });
    if (invoiceId === null) return emptyList(page, limit);
    if (invoiceId) {
      where.invoice_id = invoiceId;
    }
  }

  const [subscriptionInvoices, total] = await Promise.all([
    subscriptionInvoiceRepository.findMany(where, skip, limit, orderBy, INVOICE_INCLUDE),
    subscriptionInvoiceRepository.count(where),
  ]);

  const totalPages = Math.ceil(total / limit);

  return {
    subscriptionInvoices: subscriptionInvoices.map(serializeSubscriptionInvoice),
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1,
    },
  };
};

const createSubscriptionInvoice = async (data, user, ip) => {
  const scope = requireTenantScope(user);
  const created = await subscriptionInvoiceRepository.create({
    ...(await resolveSubscriptionInvoicePayload(data, user, scope.tenant_id)),
    human_friendly_id:
      data.human_friendly_id
      || createSubscriptionPublicId(PUBLIC_ID_PREFIXES.subscription_invoice),
  });
  const subscriptionInvoice = await loadSubscriptionInvoiceRecord(created.id, user);

  await createAuditLog({
    tenant_id: subscriptionInvoice.subscription?.tenant_id || null,
    user_id: user?.id || null,
    action: 'CREATE',
    entity: 'subscription_invoice',
    entity_id: subscriptionInvoice.id,
    diff: { after: subscriptionInvoice },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscriptionInvoice(subscriptionInvoice);
};

const updateSubscriptionInvoice = async (id, data, user, ip) => {
  const before = await loadSubscriptionInvoiceRecord(id, user);
  await subscriptionInvoiceRepository.update(
    before.id,
    await resolveSubscriptionInvoicePayload(
      data,
      user,
      before.subscription?.tenant_id
    )
  );
  const subscriptionInvoice = await loadSubscriptionInvoiceRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.subscription?.tenant_id || null,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription_invoice',
    entity_id: subscriptionInvoice.id,
    diff: { before, after: subscriptionInvoice },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscriptionInvoice(subscriptionInvoice);
};

const deleteSubscriptionInvoice = async (id, user, ip) => {
  const before = await loadSubscriptionInvoiceRecord(id, user);
  const subscriptionInvoice = await subscriptionInvoiceRepository.softDelete(before.id);

  await createAuditLog({
    tenant_id: before.subscription?.tenant_id || null,
    user_id: user?.id || null,
    action: 'DELETE',
    entity: 'subscription_invoice',
    entity_id: subscriptionInvoice.id,
    diff: { before, after: subscriptionInvoice },
    ip_address: ip,
  }).catch(() => {});

  return subscriptionInvoice;
};

const collectSubscriptionInvoice = async (id, data = {}, user, ip) => {
  const subscriptionInvoice = await loadSubscriptionInvoiceRecord(id, user);
  const serializedInvoice = serializeSubscriptionInvoice(subscriptionInvoice);
  const collectedAt = new Date().toISOString();

  await createAuditLog({
    tenant_id: subscriptionInvoice.subscription?.tenant_id || null,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription_invoice',
    entity_id: subscriptionInvoice.id,
    diff: {
      before: subscriptionInvoice,
      metadata: {
        event: 'collect',
        payment_method: data.payment_method || null,
        notes: data.notes || null,
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscriptionInvoiceCollection({
    subscription_invoice_id: serializedInvoice.id,
    collected: true,
    collected_at: collectedAt,
    payment_method: data.payment_method || null,
    version: serializedInvoice.version,
    updated_at: serializedInvoice.updated_at,
    subscription_invoice: serializedInvoice,
  });
};

const retrySubscriptionInvoice = async (id, data = {}, user, ip) => {
  const subscriptionInvoice = await loadSubscriptionInvoiceRecord(id, user);
  const serializedInvoice = serializeSubscriptionInvoice(subscriptionInvoice);
  const retriedAt = new Date().toISOString();

  await createAuditLog({
    tenant_id: subscriptionInvoice.subscription?.tenant_id || null,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription_invoice',
    entity_id: subscriptionInvoice.id,
    diff: {
      before: subscriptionInvoice,
      metadata: {
        event: 'retry',
        retry_reason: data.retry_reason || null,
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscriptionInvoiceCollection({
    subscription_invoice_id: serializedInvoice.id,
    retried: true,
    retried_at: retriedAt,
    retry_reason: data.retry_reason || null,
    version: serializedInvoice.version,
    updated_at: serializedInvoice.updated_at,
    subscription_invoice: serializedInvoice,
  });
};

module.exports = {
  getSubscriptionInvoiceById,
  listSubscriptionInvoices,
  createSubscriptionInvoice,
  updateSubscriptionInvoice,
  deleteSubscriptionInvoice,
  collectSubscriptionInvoice,
  retrySubscriptionInvoice,
};
