/**
 * Data processing log service
 *
 * @module modules/data-processing-log/services
 */

const dataProcessingLogRepository = require('@modules/data-processing-log/repositories/data-processing-log.repository');
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
const SORT_FIELDS = new Set(['processed_at', 'created_at', 'updated_at', 'purpose', 'legal_basis']);

const normalizeString = (value) => String(value || '').trim();
const normalizeOrder = (value) => (normalizeString(value).toLowerCase() === 'asc' ? 'asc' : 'desc');
const normalizeSortField = (value) => (SORT_FIELDS.has(normalizeString(value)) ? normalizeString(value) : 'processed_at');
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
  };
};

const mapUserLabel = (user = {}) => {
  const fullName = [normalizeString(user.first_name), normalizeString(user.last_name)]
    .filter(Boolean)
    .join(' ');
  return fullName || normalizeString(user.email) || null;
};

const mapDataProcessingLog = (record = {}) => {
  const publicId = safePublicId(record.human_friendly_id, record.id);
  return {
    id: publicId,
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: normalizeString(record?.tenant?.name) || null,
    user_id: safePublicId(record?.user?.human_friendly_id, record.user_id),
    user_label: mapUserLabel(record?.user || {}),
    purpose: record.purpose || null,
    legal_basis: record.legal_basis || null,
    details: record.details || null,
    processed_at: record.processed_at || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
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

const resolveDataProcessingLogId = async (identifier, user = {}) => {
  const tenantId = getUserTenantId(user);
  const where = !hasElevatedRole(user) && tenantId ? { tenant_id: tenantId } : {};
  const resolved = await resolveModelIdByIdentifier({
    model: 'data_processing_log',
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

  if (filters.purpose) {
    scopedWhere.purpose = filters.purpose;
  }
  if (filters.legal_basis) {
    scopedWhere.legal_basis = filters.legal_basis;
  }

  if (filters.date_from || filters.date_to) {
    const fromDate = normalizeDate(filters.date_from);
    const toDate = normalizeDate(filters.date_to);
    if (fromDate || toDate) {
      scopedWhere.processed_at = {};
      if (fromDate) scopedWhere.processed_at.gte = fromDate;
      if (toDate) scopedWhere.processed_at.lte = toDate;
    }
  }

  const search = normalizeString(filters.search);
  if (search) {
    const searchUpper = search.toUpperCase();
    scopedWhere.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { details: { contains: search } },
      { user: { email: { contains: search } } },
      { user: { first_name: { contains: search } } },
      { user: { last_name: { contains: search } } },
    ];
    if (['TREATMENT', 'BILLING', 'OPERATIONS', 'RESEARCH', 'MARKETING'].includes(searchUpper)) {
      scopedWhere.OR.push({ purpose: searchUpper });
    }
    if (
      [
        'CONSENT',
        'CONTRACT',
        'LEGAL_OBLIGATION',
        'VITAL_INTERESTS',
        'PUBLIC_INTEREST',
        'LEGITIMATE_INTERESTS',
      ].includes(searchUpper)
    ) {
      scopedWhere.OR.push({ legal_basis: searchUpper });
    }
  }

  return { where: scopedWhere, pagination: null };
};

const findScopedRecordByIdentifier = async (id, user = {}) => {
  const resolvedId = await resolveDataProcessingLogId(id, user);
  const tenantId = getUserTenantId(user);
  const where = { id: resolvedId };
  if (!hasElevatedRole(user) && tenantId) {
    where.tenant_id = tenantId;
  }
  const records = await dataProcessingLogRepository.findMany(
    where,
    0,
    1,
    { processed_at: 'desc' },
    includeRelations
  );
  return Array.isArray(records) ? records[0] : null;
};

const getDataProcessingLogById = async (id, user = {}) => {
  const dataProcessingLog = await findScopedRecordByIdentifier(id, user);
  if (!dataProcessingLog) {
    throw new HttpError('errors.data_processing_log.not_found', 404);
  }
  return mapDataProcessingLog(dataProcessingLog);
};

const getDataProcessingLogs = async (filters = {}, page = 1, limit = 20, sortBy = 'processed_at', order = 'desc', user = {}) => {
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
  const [dataProcessingLogs, total] = await Promise.all([
    dataProcessingLogRepository.findMany(scoped.where, skip, numericLimit, orderBy, includeRelations),
    dataProcessingLogRepository.count(scoped.where),
  ]);

  return {
    data: dataProcessingLogs.map(mapDataProcessingLog),
    total,
    page: numericPage,
    limit: numericLimit,
    totalPages: numericLimit > 0 ? Math.ceil(total / numericLimit) : 0,
  };
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
      : elevated
      ? actorUserId || null
      : actorUserId;

  return {
    tenant_id: tenantId,
    user_id: userId,
    purpose: data.purpose,
    legal_basis: data.legal_basis,
    details: data.details || null,
  };
};

const createDataProcessingLog = async (data, user = {}, ipAddress) => {
  const payload = await resolveCreatePayload(data, user);
  const createdLog = await dataProcessingLogRepository.create(payload);

  createAuditLog({
    tenant_id: payload.tenant_id,
    user_id: getActorUserId(user),
    action: 'CREATE',
    entity: 'data_processing_log',
    entity_id: createdLog.id,
    diff: { after: createdLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const createdRecord = await findScopedRecordByIdentifier(createdLog.id, {
    ...user,
    tenant_id: payload.tenant_id,
  });
  return mapDataProcessingLog(createdRecord || createdLog);
};

const updateDataProcessingLog = async (id, data, user = {}, ipAddress) => {
  const existingLog = await findScopedRecordByIdentifier(id, user);
  if (!existingLog) {
    throw new HttpError('errors.data_processing_log.not_found', 404);
  }

  const payload = {};
  if (Object.prototype.hasOwnProperty.call(data, 'purpose')) {
    payload.purpose = data.purpose;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'legal_basis')) {
    payload.legal_basis = data.legal_basis;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'details')) {
    payload.details = data.details || null;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'user_id')) {
    payload.user_id = await resolveIdentifierForPayload({
      value: data.user_id,
      model: 'user',
      field: 'user_id',
      where: { tenant_id: existingLog.tenant_id, deleted_at: null },
      nullable: true,
    });
  }

  const updatedLog = await dataProcessingLogRepository.update(existingLog.id, payload);

  createAuditLog({
    tenant_id: existingLog.tenant_id,
    user_id: getActorUserId(user),
    action: 'UPDATE',
    entity: 'data_processing_log',
    entity_id: existingLog.id,
    diff: { before: existingLog, after: updatedLog },
    ip_address: ipAddress,
  }).catch(() => {});

  const updatedRecord = await findScopedRecordByIdentifier(updatedLog.id, {
    ...user,
    tenant_id: existingLog.tenant_id,
  });
  return mapDataProcessingLog(updatedRecord || updatedLog);
};

const deleteDataProcessingLog = async (id, user = {}, ipAddress) => {
  const existingLog = await findScopedRecordByIdentifier(id, user);
  if (!existingLog) {
    throw new HttpError('errors.data_processing_log.not_found', 404);
  }

  const deletedLog = await dataProcessingLogRepository.softDelete(existingLog.id);

  createAuditLog({
    tenant_id: existingLog.tenant_id,
    user_id: getActorUserId(user),
    action: 'DELETE',
    entity: 'data_processing_log',
    entity_id: existingLog.id,
    diff: { before: existingLog, after: deletedLog },
    ip_address: ipAddress,
  }).catch(() => {});

  return mapDataProcessingLog(existingLog);
};

module.exports = {
  getDataProcessingLogById,
  getDataProcessingLogs,
  createDataProcessingLog,
  updateDataProcessingLog,
  deleteDataProcessingLog,
};
