/**
 * System change log service
 *
 * @module modules/system-change-log/services
 */

const systemChangeLogRepository = require('@repositories/system-change-log/system-change-log.repository');
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
const SORT_FIELDS = new Set(['created_at', 'updated_at', 'change_type']);

const normalizeString = (value) => String(value || '').trim();
const normalizeOrder = (value) => (normalizeString(value).toLowerCase() === 'asc' ? 'asc' : 'desc');
const normalizeSortField = (value) => (SORT_FIELDS.has(normalizeString(value)) ? normalizeString(value) : 'created_at');
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
  user: {
    select: {
      id: true,
      human_friendly_id: true,
      email: true,
      first_name: true,
      last_name: true,
    },
  },
};

const mapUserLabel = (user = {}) => {
  const fullName = [normalizeString(user.first_name), normalizeString(user.last_name)]
    .filter(Boolean)
    .join(' ');
  return fullName || normalizeString(user.email) || null;
};

const mapSystemChangeLog = (record = {}) => {
  const publicId = safePublicId(record.human_friendly_id, record.id);
  return {
    id: publicId,
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: normalizeString(record?.tenant?.name) || null,
    user_id: safePublicId(record?.user?.human_friendly_id, record.user_id),
    user_label: mapUserLabel(record?.user || {}),
    change_type: record.change_type || null,
    details: record.details || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
  };
};

const resolveSystemChangeLogId = async (identifier, user = {}) => {
  const tenantId = getUserTenantId(user);
  const where = !hasElevatedRole(user) && tenantId ? { tenant_id: tenantId } : {};
  const resolved = await resolveModelIdByIdentifier({
    model: 'system_change_log',
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

  if (filters.user_id !== undefined) {
    const resolvedUserId = await resolveIdentifierForFilter({
      value: filters.user_id,
      model: 'user',
      where: scopedWhere.tenant_id ? { tenant_id: scopedWhere.tenant_id, deleted_at: null } : { deleted_at: null },
    });
    if (resolvedUserId === null) {
      return { where: null, pagination: buildPagination(page, limit, 0) };
    }
    if (resolvedUserId !== undefined) {
      scopedWhere.user_id = resolvedUserId;
    }
  }

  if (filters.change_type) {
    scopedWhere.change_type = { contains: normalizeString(filters.change_type) };
  }

  if (filters.from_date || filters.to_date) {
    const fromDate = normalizeDate(filters.from_date);
    const toDate = normalizeDate(filters.to_date);
    if (fromDate || toDate) {
      scopedWhere.created_at = {};
      if (fromDate) scopedWhere.created_at.gte = fromDate;
      if (toDate) scopedWhere.created_at.lte = toDate;
    }
  }

  const search = normalizeString(filters.search);
  if (search) {
    scopedWhere.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { change_type: { contains: search } },
      { details: { contains: search } },
      { user: { email: { contains: search } } },
      { user: { first_name: { contains: search } } },
      { user: { last_name: { contains: search } } },
    ];
  }

  return { where: scopedWhere, pagination: null };
};

const findScopedRecordByIdentifier = async (id, user = {}) => {
  const resolvedId = await resolveSystemChangeLogId(id, user);
  const tenantId = getUserTenantId(user);
  const where = { id: resolvedId };
  if (!hasElevatedRole(user) && tenantId) {
    where.tenant_id = tenantId;
  }
  const records = await systemChangeLogRepository.findMany(
    where,
    0,
    1,
    { created_at: 'desc' },
    includeRelations
  );
  return Array.isArray(records) ? records[0] : null;
};

const listSystemChangeLogs = async (filters = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const numericPage = Number(page) > 0 ? Number(page) : 1;
  const numericLimit = Number(limit) > 0 ? Number(limit) : 20;
  const scoped = await resolveScopedFilters(filters, user, numericPage, numericLimit);
  if (scoped.where === null) {
    return {
      systemChangeLogs: [],
      pagination: buildPagination(numericPage, numericLimit, 0),
    };
  }

  const skip = (numericPage - 1) * numericLimit;
  const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };

  const [systemChangeLogs, total] = await Promise.all([
    systemChangeLogRepository.findMany(scoped.where, skip, numericLimit, orderBy, includeRelations),
    systemChangeLogRepository.count(scoped.where),
  ]);

  return {
    systemChangeLogs: systemChangeLogs.map(mapSystemChangeLog),
    pagination: buildPagination(numericPage, numericLimit, total),
  };
};

const getSystemChangeLogById = async (id, user = {}) => {
  const systemChangeLog = await findScopedRecordByIdentifier(id, user);
  if (!systemChangeLog) {
    throw new HttpError('errors.system_change_log.not_found', 404);
  }
  return mapSystemChangeLog(systemChangeLog);
};

const resolveCreatePayload = async (data = {}, user = {}) => {
  const elevated = hasElevatedRole(user);
  const actorTenantId = getUserTenantId(user);
  const actorUserId = getActorUserId(user);

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

  const userId =
    data.user_id !== undefined
      ? await resolveIdentifierForPayload({
          value: data.user_id,
          model: 'user',
          field: 'user_id',
          where: { tenant_id: tenantId, deleted_at: null },
          nullable: true,
        })
      : actorUserId || null;

  return {
    tenant_id: tenantId,
    user_id: userId,
    change_type: data.change_type,
    details: data.details || null,
  };
};

const createSystemChangeLog = async (data, user = {}, ipAddress) => {
  const payload = await resolveCreatePayload(data, user);
  const systemChangeLog = await systemChangeLogRepository.create(payload);

  createAuditLog({
    tenant_id: payload.tenant_id,
    user_id: getActorUserId(user),
    action: 'CREATE',
    entity: 'system_change_log',
    entity_id: systemChangeLog.id,
    diff: { after: systemChangeLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const createdRecord = await findScopedRecordByIdentifier(systemChangeLog.id, {
    ...user,
    tenant_id: payload.tenant_id,
  });
  return mapSystemChangeLog(createdRecord || systemChangeLog);
};

const updateSystemChangeLog = async (id, data, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.system_change_log.not_found', 404);
  }

  const payload = {};
  if (Object.prototype.hasOwnProperty.call(data, 'change_type')) {
    payload.change_type = data.change_type;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'details')) {
    payload.details = data.details || null;
  }

  const systemChangeLog = await systemChangeLogRepository.update(before.id, payload);

  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'system_change_log',
    entity_id: before.id,
    diff: { before, after: systemChangeLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(systemChangeLog.id, {
    ...user,
    tenant_id: before.tenant_id,
  });
  return mapSystemChangeLog(updatedRecord || systemChangeLog);
};

const appendMetadataLine = (details, marker, payload) => {
  const currentDetails = normalizeString(details);
  const markerLine = `[${marker}] ${JSON.stringify(payload)}`;
  return currentDetails ? `${currentDetails}\n\n${markerLine}` : markerLine;
};

const approveSystemChangeLog = async (id, approvalNotes, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.system_change_log.not_found', 404);
  }

  const approvalMetadata = {
    approved_by: safePublicId(user?.human_friendly_id, getActorUserId(user)),
    approved_at: new Date().toISOString(),
    approval_notes: approvalNotes || 'Approved',
  };

  const systemChangeLog = await systemChangeLogRepository.update(before.id, {
    details: appendMetadataLine(before.details, 'APPROVED', approvalMetadata),
  });

  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'system_change_log',
    entity_id: before.id,
    diff: { before, after: systemChangeLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(systemChangeLog.id, {
    ...user,
    tenant_id: before.tenant_id,
  });
  return mapSystemChangeLog(updatedRecord || systemChangeLog);
};

const implementSystemChangeLog = async (id, implementationNotes, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.system_change_log.not_found', 404);
  }

  const implementationMetadata = {
    implemented_by: safePublicId(user?.human_friendly_id, getActorUserId(user)),
    implemented_at: new Date().toISOString(),
    implementation_notes: implementationNotes || 'Implemented',
  };

  const systemChangeLog = await systemChangeLogRepository.update(before.id, {
    details: appendMetadataLine(before.details, 'IMPLEMENTED', implementationMetadata),
  });

  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'system_change_log',
    entity_id: before.id,
    diff: { before, after: systemChangeLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(systemChangeLog.id, {
    ...user,
    tenant_id: before.tenant_id,
  });
  return mapSystemChangeLog(updatedRecord || systemChangeLog);
};

const deleteSystemChangeLog = async (id, user = {}, ipAddress) => {
  const before = await findScopedRecordByIdentifier(id, user);
  if (!before) {
    throw new HttpError('errors.system_change_log.not_found', 404);
  }

  const deleted = await systemChangeLogRepository.softDelete(before.id);
  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: getActorUserId(user),
    action: 'DELETE',
    entity: 'system_change_log',
    entity_id: before.id,
    diff: { before, after: deleted },
    ip_address: ipAddress,
  }).catch(() => {});
};

module.exports = {
  listSystemChangeLogs,
  getSystemChangeLogById,
  createSystemChangeLog,
  updateSystemChangeLog,
  approveSystemChangeLog,
  implementSystemChangeLog,
  deleteSystemChangeLog,
};
