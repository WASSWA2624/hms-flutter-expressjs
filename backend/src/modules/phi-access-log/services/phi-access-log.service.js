/**
 * PHI access log service
 *
 * @module modules/phi-access-log/services
 */

const phiAccessLogRepository = require('@modules/phi-access-log/repositories/phi-access-log.repository');
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
const SORT_FIELDS = new Set(['accessed_at', 'created_at', 'updated_at', 'access_scope']);

const normalizeString = (value) => String(value || '').trim();
const normalizeOrder = (value) => (normalizeString(value).toLowerCase() === 'asc' ? 'asc' : 'desc');
const normalizeSortField = (value) => (SORT_FIELDS.has(normalizeString(value)) ? normalizeString(value) : 'accessed_at');
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
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
    },
  },
};

const buildPagination = (page, limit, total) => {
  const totalPages = limit > 0 ? Math.ceil(total / limit) : 0;
  return {
    page,
    limit,
    total,
    totalPages,
  };
};

const mapUserLabel = (user = {}) => {
  const fullName = [normalizeString(user.first_name), normalizeString(user.last_name)]
    .filter(Boolean)
    .join(' ');
  return fullName || normalizeString(user.email) || null;
};

const mapPatientLabel = (patient = {}) => {
  const fullName = [normalizeString(patient.first_name), normalizeString(patient.last_name)]
    .filter(Boolean)
    .join(' ');
  return fullName || null;
};

const mapPhiAccessLog = (record = {}) => {
  const publicId = safePublicId(record.human_friendly_id, record.id);
  return {
    id: publicId,
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: normalizeString(record?.tenant?.name) || null,
    user_id: safePublicId(record?.user?.human_friendly_id, record.user_id),
    user_label: mapUserLabel(record?.user || {}),
    patient_id: safePublicId(record?.patient?.human_friendly_id, record.patient_id),
    patient_label: mapPatientLabel(record?.patient || {}),
    access_scope: record.access_scope || null,
    reason: record.reason || null,
    accessed_at: record.accessed_at || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
  };
};

const resolvePhiAccessLogId = async (identifier, user = {}) => {
  const tenantId = getUserTenantId(user);
  const where = !hasElevatedRole(user) && tenantId ? { tenant_id: tenantId } : {};
  const resolved = await resolveModelIdByIdentifier({
    model: 'phi_access_log',
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

  if (filters.patient_id !== undefined) {
    const resolvedPatientId = await resolveIdentifierForFilter({
      value: filters.patient_id,
      model: 'patient',
      where: scopedWhere.tenant_id ? { tenant_id: scopedWhere.tenant_id, deleted_at: null } : { deleted_at: null },
    });
    if (resolvedPatientId === null) {
      return { where: null, pagination: buildPagination(page, limit, 0) };
    }
    if (resolvedPatientId !== undefined) {
      scopedWhere.patient_id = resolvedPatientId;
    }
  }

  if (filters.access_scope) {
    scopedWhere.access_scope = filters.access_scope;
  }

  if (filters.date_from || filters.date_to) {
    const fromDate = normalizeDate(filters.date_from);
    const toDate = normalizeDate(filters.date_to);
    if (fromDate || toDate) {
      scopedWhere.accessed_at = {};
      if (fromDate) scopedWhere.accessed_at.gte = fromDate;
      if (toDate) scopedWhere.accessed_at.lte = toDate;
    }
  }

  const search = normalizeString(filters.search);
  if (search) {
    scopedWhere.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { reason: { contains: search } },
      { user: { email: { contains: search } } },
      { user: { first_name: { contains: search } } },
      { user: { last_name: { contains: search } } },
      { patient: { first_name: { contains: search } } },
      { patient: { last_name: { contains: search } } },
      { patient: { human_friendly_id: { contains: search.toUpperCase() } } },
    ];
  }

  return { where: scopedWhere, pagination: null };
};

const findScopedRecordByIdentifier = async (id, user = {}) => {
  const resolvedId = await resolvePhiAccessLogId(id, user);
  const tenantId = getUserTenantId(user);
  const where = { id: resolvedId };
  if (!hasElevatedRole(user) && tenantId) {
    where.tenant_id = tenantId;
  }
  const records = await phiAccessLogRepository.findMany(
    where,
    0,
    1,
    { accessed_at: 'desc' },
    includeRelations
  );
  return Array.isArray(records) ? records[0] : null;
};

const getPhiAccessLogById = async (id, user = {}) => {
  const phiAccessLog = await findScopedRecordByIdentifier(id, user);
  if (!phiAccessLog) {
    throw new HttpError('errors.phi_access_log.not_found', 404);
  }
  return mapPhiAccessLog(phiAccessLog);
};

const getPhiAccessLogs = async (filters = {}, page = 1, limit = 20, sortBy = 'accessed_at', order = 'desc', user = {}) => {
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
  const [phiAccessLogs, total] = await Promise.all([
    phiAccessLogRepository.findMany(scoped.where, skip, numericLimit, orderBy, includeRelations),
    phiAccessLogRepository.count(scoped.where),
  ]);

  return {
    data: phiAccessLogs.map(mapPhiAccessLog),
    total,
    page: numericPage,
    limit: numericLimit,
    totalPages: numericLimit > 0 ? Math.ceil(total / numericLimit) : 0,
  };
};

const getPhiAccessLogsByUserId = async (userId, page = 1, limit = 20, sortBy = 'accessed_at', order = 'desc', user = {}) =>
  getPhiAccessLogs({ user_id: userId }, page, limit, sortBy, order, user);

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

  const userId = elevated
    ? await resolveIdentifierForPayload({
        value: data.user_id || actorUserId,
        model: 'user',
        field: 'user_id',
        where: { tenant_id: tenantId, deleted_at: null },
      })
    : actorUserId;

  if (!userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const patientId = await resolveIdentifierForPayload({
    value: data.patient_id,
    model: 'patient',
    field: 'patient_id',
    where: { tenant_id: tenantId, deleted_at: null },
  });

  return {
    tenant_id: tenantId,
    user_id: userId,
    patient_id: patientId,
    access_scope: data.access_scope,
    reason: data.reason || null,
  };
};

const createPhiAccessLog = async (data, user = {}, ipAddress) => {
  const payload = await resolveCreatePayload(data, user);
  const createdLog = await phiAccessLogRepository.create(payload);

  createAuditLog({
    tenant_id: payload.tenant_id,
    user_id: getActorUserId(user),
    action: 'CREATE',
    entity: 'phi_access_log',
    entity_id: createdLog.id,
    diff: { after: createdLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const createdRecord = await findScopedRecordByIdentifier(createdLog.id, {
    ...user,
    tenant_id: payload.tenant_id,
  });
  return mapPhiAccessLog(createdRecord || createdLog);
};

const updatePhiAccessLog = async (id, data, user = {}, ipAddress) => {
  const existingLog = await findScopedRecordByIdentifier(id, user);
  if (!existingLog) {
    throw new HttpError('errors.phi_access_log.not_found', 404);
  }

  const payload = {};
  if (Object.prototype.hasOwnProperty.call(data, 'access_scope')) {
    payload.access_scope = data.access_scope;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'reason')) {
    payload.reason = data.reason || null;
  }

  const updatedLog = await phiAccessLogRepository.update(existingLog.id, payload);

  createAuditLog({
    tenant_id: existingLog.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'phi_access_log',
    entity_id: existingLog.id,
    diff: { before: existingLog, after: updatedLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(updatedLog.id, {
    ...user,
    tenant_id: existingLog.tenant_id,
  });
  return mapPhiAccessLog(updatedRecord || updatedLog);
};

const deletePhiAccessLog = async (id, user = {}, ipAddress) => {
  const existingLog = await findScopedRecordByIdentifier(id, user);
  if (!existingLog) {
    throw new HttpError('errors.phi_access_log.not_found', 404);
  }

  const deletedLog = await phiAccessLogRepository.softDelete(existingLog.id);

  createAuditLog({
    tenant_id: existingLog.tenant_id,
    user_id: getActorUserId(user),
    action: 'DELETE',
    entity: 'phi_access_log',
    entity_id: existingLog.id,
    diff: { before: existingLog, after: deletedLog },
    ip_address: ipAddress,
  }).catch(() => {});

  return mapPhiAccessLog(existingLog);
};

module.exports = {
  getPhiAccessLogById,
  getPhiAccessLogs,
  getPhiAccessLogsByUserId,
  createPhiAccessLog,
  updatePhiAccessLog,
  deletePhiAccessLog,
};
