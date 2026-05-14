/**
 * Breach notification service
 *
 * @module modules/breach-notification/services
 */

const breachNotificationRepository = require('@repositories/breach-notification/breach-notification.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolvePublicIdentifier,
} = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { ELEVATED_ROLES, normalizeRoleName } = require('@config/roles');

const ELEVATED_ROLE_SET = new Set(ELEVATED_ROLES);
const SORT_FIELDS = new Set(['reported_at', 'created_at', 'updated_at', 'severity', 'status']);

const normalizeString = (value) => String(value || '').trim();
const normalizeOrder = (value) => (normalizeString(value).toLowerCase() === 'asc' ? 'asc' : 'desc');
const normalizeSortField = (value) => (SORT_FIELDS.has(normalizeString(value)) ? normalizeString(value) : 'reported_at');
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;
const getUserTenantId = (user = {}) => normalizeString(user?.tenant_id || user?.tenantId) || null;
const getActorUserId = (user = {}) => normalizeString(user?.id) || null;
const normalizeDate = (value) => {
  const normalized = normalizeString(value);
  if (!normalized) return null;
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
};

const hasElevatedRole = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : user.role ? [user.role] : [];
  return roles.some((role) => {
    const normalized = normalizeRoleName(role) || String(role || '').trim().toUpperCase();
    return ELEVATED_ROLE_SET.has(normalized);
  });
};

const buildPagination = (page, limit, total) => {
  const totalPages = limit > 0 ? Math.ceil(total / limit) : 0;
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const includeRelations = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
};

const mapBreachNotification = (record = {}) => {
  const publicId = safePublicId(record.human_friendly_id, record.id);
  return {
    id: publicId,
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: normalizeString(record?.tenant?.name) || null,
    severity: record.severity || null,
    status: record.status || null,
    description: record.description || null,
    reported_at: record.reported_at || null,
    resolved_at: record.resolved_at || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
  };
};

const resolveBreachNotificationId = async (identifier, user = {}) => {
  const tenantId = getUserTenantId(user);
  const where = !hasElevatedRole(user) && tenantId ? { tenant_id: tenantId } : {};
  const resolved = await resolveModelIdByIdentifier({
    model: 'breach_notification',
    identifier,
    where,
  });
  return resolved || identifier;
};

const resolveScopedFilters = async (filters = {}, user = {}, page = 1, limit = 20) => {
  const scopedWhere = {};
  const elevated = hasElevatedRole(user);
  const userTenantId = getUserTenantId(user);

  if (!elevated && userTenantId) {
    scopedWhere.tenant_id = userTenantId;
  }

  if (filters.tenant_id !== undefined) {
    const resolvedTenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
    });
    if (resolvedTenantId === null) {
      return { where: null, pagination: buildPagination(page, limit, 0) };
    }
    if (resolvedTenantId !== undefined) {
      if (!elevated && userTenantId && resolvedTenantId !== userTenantId) {
        return { where: null, pagination: buildPagination(page, limit, 0) };
      }
      scopedWhere.tenant_id = resolvedTenantId;
    }
  }

  if (filters.severity) scopedWhere.severity = filters.severity;
  if (filters.status) scopedWhere.status = filters.status;

  if (filters.from_date || filters.to_date) {
    const fromDate = normalizeDate(filters.from_date);
    const toDate = normalizeDate(filters.to_date);
    if (fromDate || toDate) {
      scopedWhere.reported_at = {};
      if (fromDate) scopedWhere.reported_at.gte = fromDate;
      if (toDate) scopedWhere.reported_at.lte = toDate;
    }
  }

  const search = normalizeString(filters.search);
  if (search) {
    const searchUpper = search.toUpperCase();
    scopedWhere.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { description: { contains: search } },
    ];
    if (['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(searchUpper)) {
      scopedWhere.OR.push({ severity: searchUpper });
    }
    if (['OPEN', 'INVESTIGATING', 'RESOLVED', 'REPORTED'].includes(searchUpper)) {
      scopedWhere.OR.push({ status: searchUpper });
    }
  }

  return { where: scopedWhere, pagination: null };
};

const findScopedRecordByIdentifier = async (id, user = {}) => {
  const resolvedId = await resolveBreachNotificationId(id, user);
  const tenantId = getUserTenantId(user);
  const where = { id: resolvedId };
  if (!hasElevatedRole(user) && tenantId) {
    where.tenant_id = tenantId;
  }
  const records = await breachNotificationRepository.findMany(
    where,
    0,
    1,
    { reported_at: 'desc' },
    includeRelations
  );
  return Array.isArray(records) ? records[0] : null;
};

const listBreachNotifications = async (filters = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const numericPage = Number(page) > 0 ? Number(page) : 1;
  const numericLimit = Number(limit) > 0 ? Number(limit) : 20;
  const scoped = await resolveScopedFilters(filters, user, numericPage, numericLimit);
  if (scoped.where === null) {
    return {
      breachNotifications: [],
      pagination: buildPagination(numericPage, numericLimit, 0),
    };
  }

  const skip = (numericPage - 1) * numericLimit;
  const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };

  const [breachNotifications, total] = await Promise.all([
    breachNotificationRepository.findMany(scoped.where, skip, numericLimit, orderBy, includeRelations),
    breachNotificationRepository.count(scoped.where),
  ]);

  return {
    breachNotifications: breachNotifications.map(mapBreachNotification),
    pagination: buildPagination(numericPage, numericLimit, total),
  };
};

const getBreachNotificationById = async (id, user = {}) => {
  const breachNotification = await findScopedRecordByIdentifier(id, user);
  if (!breachNotification) {
    throw new HttpError('errors.breach_notification.not_found', 404);
  }
  return mapBreachNotification(breachNotification);
};

const resolveCreatePayload = async (data = {}, user = {}) => {
  const elevated = hasElevatedRole(user);
  const actorTenantId = getUserTenantId(user);

  if (!elevated && !actorTenantId) {
    throw new HttpError('errors.auth.forbidden', 403);
  }

  const tenantId = elevated
    ? await resolveIdentifierForPayload({
        value: data.tenant_id || actorTenantId,
        model: 'tenant',
        field: 'tenant_id',
        where: { deleted_at: null },
      })
    : actorTenantId;

  return {
    tenant_id: tenantId,
    severity: data.severity,
    status: data.status || 'OPEN',
    description: data.description || null,
    reported_at: data.reported_at ? new Date(data.reported_at) : undefined,
  };
};

const createBreachNotification = async (data, user = {}, ipAddress) => {
  const payload = await resolveCreatePayload(data, user);
  const breachNotification = await breachNotificationRepository.create(payload);

  createAuditLog({
    tenant_id: payload.tenant_id,
    user_id: getActorUserId(user),
    action: 'CREATE',
    entity: 'breach_notification',
    entity_id: breachNotification.id,
    diff: { after: breachNotification },
    ip_address: ipAddress,
  }).catch(() => {});

  const createdRecord = await findScopedRecordByIdentifier(breachNotification.id, {
    ...user,
    tenant_id: payload.tenant_id,
  });
  return mapBreachNotification(createdRecord || breachNotification);
};

const updateBreachNotification = async (id, data, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.breach_notification.not_found', 404);
  }

  const payload = {};
  if (Object.prototype.hasOwnProperty.call(data, 'severity')) payload.severity = data.severity;
  if (Object.prototype.hasOwnProperty.call(data, 'status')) payload.status = data.status;
  if (Object.prototype.hasOwnProperty.call(data, 'description')) payload.description = data.description || null;
  if (Object.prototype.hasOwnProperty.call(data, 'reported_at')) {
    payload.reported_at = data.reported_at ? new Date(data.reported_at) : undefined;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'resolved_at')) {
    payload.resolved_at = data.resolved_at ? new Date(data.resolved_at) : null;
  }

  const breachNotification = await breachNotificationRepository.update(before.id, payload);

  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'breach_notification',
    entity_id: before.id,
    diff: { before, after: breachNotification },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(breachNotification.id, {
    ...user,
    tenant_id: before.tenant_id,
  });
  return mapBreachNotification(updatedRecord || breachNotification);
};

const resolveBreachNotification = async (id, resolvedAt, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.breach_notification.not_found', 404);
  }
  if (before.status === 'RESOLVED') {
    throw new HttpError('errors.breach_notification.already_resolved', 400);
  }

  const breachNotification = await breachNotificationRepository.update(before.id, {
    status: 'RESOLVED',
    resolved_at: resolvedAt || new Date(),
  });

  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'breach_notification',
    entity_id: before.id,
    diff: { before, after: breachNotification },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(breachNotification.id, {
    ...user,
    tenant_id: before.tenant_id,
  });
  return mapBreachNotification(updatedRecord || breachNotification);
};

const deleteBreachNotification = async (id, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.breach_notification.not_found', 404);
  }

  const deleted = await breachNotificationRepository.softDelete(before.id);
  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'DELETE',
    entity: 'breach_notification',
    entity_id: before.id,
    diff: { before, after: deleted },
    ip_address: ipAddress,
  }).catch(() => {});
};

module.exports = {
  listBreachNotifications,
  getBreachNotificationById,
  createBreachNotification,
  updateBreachNotification,
  resolveBreachNotification,
  deleteBreachNotification,
};
