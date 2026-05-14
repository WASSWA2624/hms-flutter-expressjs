/**
 * Audit log service
 *
 * @module modules/audit-log/services
 */

const auditLogRepository = require('@modules/audit-log/repositories/audit-log.repository');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { ELEVATED_ROLES, normalizeRoleName } = require('@config/roles');

const ELEVATED_ROLE_SET = new Set(ELEVATED_ROLES);
const SORT_FIELDS = new Set(['created_at', 'updated_at', 'action', 'entity']);

const normalizeString = (value) => String(value || '').trim();
const normalizeOrder = (value) => (normalizeString(value).toLowerCase() === 'asc' ? 'asc' : 'desc');
const normalizeSortField = (value) => (SORT_FIELDS.has(normalizeString(value)) ? normalizeString(value) : 'created_at');
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;
const normalizeEntityModel = (value) =>
  normalizeString(value)
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
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

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
});

const mapUserLabel = (record = {}) => {
  const fullName = [normalizeString(record.first_name), normalizeString(record.last_name)]
    .filter(Boolean)
    .join(' ');
  return fullName || normalizeString(record.email) || null;
};

const mapAuditLog = (record = {}) => {
  const publicId = safePublicId(record.human_friendly_id, record.id);
  return {
    id: publicId,
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: normalizeString(record?.tenant?.name) || null,
    user_id: safePublicId(record?.user?.human_friendly_id, record.user_id),
    user_label: mapUserLabel(record?.user || {}),
    action: record.action || null,
    entity: record.entity || null,
    entity_id: safePublicId(record.entity_id),
    entity_reference: safePublicId(record.entity_id),
    diff_json: record.diff_json || null,
    ip_address: record.ip_address || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
  };
};

const resolveAuditLogId = async (identifier, user = {}) => {
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const resolved = await resolveModelIdByIdentifier({
    model: 'audit_log',
    identifier,
    where: hasElevatedRole(user) ? {} : tenantId ? { tenant_id: tenantId } : {},
  });
  return resolved || identifier;
};

const resolveScopedFilters = async (filters = {}, user = {}, page = 1, limit = 20) => {
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const resolved = {};
  const isElevated = hasElevatedRole(user);

  if (!isElevated && tenantId) {
    resolved.tenant_id = tenantId;
  }

  if (filters.tenant_id !== undefined) {
    const resolvedTenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
    });
    if (resolvedTenantId === null) {
      return { where: null, pagination: buildPagination(page, limit, 0) };
    }
    if (resolvedTenantId !== undefined) {
      if (!isElevated && tenantId && resolvedTenantId !== tenantId) {
        return { where: null, pagination: buildPagination(page, limit, 0) };
      }
      resolved.tenant_id = resolvedTenantId;
    }
  }

  if (filters.user_id !== undefined) {
    const resolvedUserId = await resolveIdentifierForFilter({
      value: filters.user_id,
      model: 'user',
      where: resolved.tenant_id ? { tenant_id: resolved.tenant_id } : {},
    });
    if (resolvedUserId === null) {
      return { where: null, pagination: buildPagination(page, limit, 0) };
    }
    if (resolvedUserId !== undefined) {
      resolved.user_id = resolvedUserId;
    }
  }

  if (filters.action) resolved.action = filters.action;
  const entityName = normalizeString(filters.entity);
  if (entityName) {
    resolved.entity = entityName;
  }

  const entityIdentifier = normalizeString(filters.entity_id);
  if (entityIdentifier) {
    let resolvedEntityId = entityIdentifier;
    const entityModel = normalizeEntityModel(entityName);
    if (entityModel) {
      const convertedEntityId = await resolveModelIdByIdentifier({
        model: entityModel,
        identifier: entityIdentifier,
        where: resolved.tenant_id ? { tenant_id: resolved.tenant_id } : {},
      });
      if (convertedEntityId) {
        resolvedEntityId = convertedEntityId;
      }
    }
    resolved.entity_id = resolvedEntityId;
  }
  if (normalizeString(filters.ip_address)) resolved.ip_address = normalizeString(filters.ip_address);

  if (filters.date_from || filters.date_to) {
    const fromDate = normalizeDate(filters.date_from);
    const toDate = normalizeDate(filters.date_to);
    if (fromDate || toDate) {
      resolved.created_at = {};
      if (fromDate) resolved.created_at.gte = fromDate;
      if (toDate) resolved.created_at.lte = toDate;
    }
  }

  const search = normalizeString(filters.search);
  if (search) {
    resolved.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { entity: { contains: search } },
      { entity_id: { contains: search } },
      { ip_address: { contains: search } },
      { user: { email: { contains: search } } },
      { user: { first_name: { contains: search } } },
      { user: { last_name: { contains: search } } },
    ];
  }

  return { where: resolved, pagination: null };
};

const getAuditLogById = async (id, user = {}) => {
  const resolvedId = await resolveAuditLogId(id, user);
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const where = {
    id: resolvedId,
  };

  if (!hasElevatedRole(user) && tenantId) {
    where.tenant_id = tenantId;
  }

  const record = await auditLogRepository.findMany(where, 0, 1, { created_at: 'desc' }, {
    tenant: { select: { id: true, human_friendly_id: true, name: true } },
    user: {
      select: {
        id: true,
        human_friendly_id: true,
        email: true,
        first_name: true,
        last_name: true,
      },
    },
  });

  const auditLog = Array.isArray(record) ? record[0] : null;
  if (!auditLog) {
    throw new HttpError('errors.audit_log.not_found', 404);
  }

  return mapAuditLog(auditLog);
};

const getAuditLogs = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc', user = {}) => {
  const numericPage = Number(page) > 0 ? Number(page) : 1;
  const numericLimit = Number(limit) > 0 ? Number(limit) : 20;

  const scoped = await resolveScopedFilters(filters, user, numericPage, numericLimit);
  if (scoped.where === null) {
    return {
      data: [],
      total: 0,
      page: numericPage,
      limit: numericLimit,
      totalPages: 0,
    };
  }

  const skip = (numericPage - 1) * numericLimit;
  const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };

  const [auditLogs, total] = await Promise.all([
    auditLogRepository.findMany(scoped.where, skip, numericLimit, orderBy, {
      tenant: { select: { id: true, human_friendly_id: true, name: true } },
      user: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          first_name: true,
          last_name: true,
        },
      },
    }),
    auditLogRepository.count(scoped.where),
  ]);

  return {
    data: auditLogs.map(mapAuditLog),
    total,
    page: numericPage,
    limit: numericLimit,
    totalPages: numericLimit > 0 ? Math.ceil(total / numericLimit) : 0,
  };
};

const getAuditLogsByUserId = async (userId, page = 1, limit = 20, sortBy = 'created_at', order = 'desc', user = {}) =>
  getAuditLogs({ user_id: userId }, page, limit, sortBy, order, user);

const getAuditLogsByEntity = async (entity, entityId, page = 1, limit = 20, sortBy = 'created_at', order = 'desc', user = {}) =>
  getAuditLogs({ entity, entity_id: entityId }, page, limit, sortBy, order, user);

module.exports = {
  getAuditLogById,
  getAuditLogs,
  getAuditLogsByUserId,
  getAuditLogsByEntity,
};
