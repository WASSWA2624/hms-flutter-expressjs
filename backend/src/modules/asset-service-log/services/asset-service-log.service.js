/**
 * Asset service log service
 *
 * @module modules/asset-service-log/services
 * @description Business logic layer for asset service log operations.
 */

const assetServiceLogRepository = require('@repositories/asset-service-log/asset-service-log.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveEntityId, resolveIdentifierForFilter, resolveIdentifierForPayload, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');

const SERVICE_LOG_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'serviced_at',
]);

const SERVICE_LOG_INCLUDE = {
  asset: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      asset_tag: true,
      tenant_id: true,
      facility_id: true,
      facility: { select: { id: true, human_friendly_id: true, name: true } },
    },
  },
};

const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object || {}, key);
const displayId = (record = {}) => resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id) || record?.id || null;
const publicRelationId = (record, relationName, fieldName) =>
  resolvePublicIdentifier(record?.[relationName]?.human_friendly_id, record?.[fieldName]) || record?.[fieldName] || null;

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const resolveOrderBy = (sortBy = 'created_at', order = 'desc') => {
  const field = SERVICE_LOG_SORT_FIELDS.has(sortBy) ? sortBy : 'created_at';
  return { [field]: order === 'asc' ? 'asc' : 'desc' };
};

const mapAssetServiceLog = (record) => {
  if (!record || typeof record !== 'object') return record;
  const id = displayId(record);
  const asset = record?.asset || null;

  return {
    ...record,
    id,
    human_friendly_id: id,
    display_id: id,
    asset_id: publicRelationId(record, 'asset', 'asset_id'),
    asset_label: asset?.name || asset?.asset_tag || null,
    facility_id:
      resolvePublicIdentifier(asset?.facility?.human_friendly_id, asset?.facility_id) || asset?.facility_id || null,
    facility_label: asset?.facility?.name || null,
  };
};

const isOutsideScope = (record, context = {}) => {
  if (!record || !record.asset) return false;
  if (context?.tenant_id && record.asset.tenant_id !== context.tenant_id) return true;
  if (context?.facility_id && record.asset.facility_id !== context.facility_id) return true;
  return false;
};

const resolveServiceLogId = (identifier) =>
  resolveEntityId({ model: 'asset_service_log', identifier });

const buildAssetScope = (context = {}) => ({
  ...(context?.tenant_id ? { tenant_id: context.tenant_id } : {}),
  ...(context?.facility_id ? { facility_id: context.facility_id } : {}),
});

const resolveListFilters = async (filters = {}, page = 1, limit = 20, context = {}) => {
  const repoFilters = {};
  const assetScope = buildAssetScope(context);

  if (filters.asset_id !== undefined) {
    const assetId = await resolveIdentifierForFilter({
      value: filters.asset_id,
      model: 'asset',
      where: assetScope,
    });
    if (assetId === null) {
      return {
        assetServiceLogs: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (assetId !== undefined) repoFilters.asset_id = assetId;
  }

  if (Object.keys(assetScope).length > 0) {
    repoFilters.asset = {
      ...assetScope,
      deleted_at: null,
    };
  }

  if (filters.search) {
    repoFilters.OR = [
      { human_friendly_id: { contains: String(filters.search).trim().toUpperCase() } },
      { notes: { contains: filters.search } },
      { asset: { name: { contains: filters.search } } },
      { asset: { asset_tag: { contains: filters.search } } },
    ];
  }

  return repoFilters;
};

const resolvePayload = async (data = {}, context = {}) => {
  const payload = { ...data };

  if (hasOwn(payload, 'asset_id')) {
    payload.asset_id = await resolveIdentifierForPayload({
      value: payload.asset_id,
      field: 'asset_id',
      model: 'asset',
      where: buildAssetScope(context),
    });
  }

  if (payload.serviced_at) {
    payload.serviced_at = new Date(payload.serviced_at);
  }

  return payload;
};

const listAssetServiceLogs = async (filters, page, limit, sortBy, order, userId, ipAddress, context = {}) => {
  try {
    const resolvedFilters = await resolveListFilters(filters, page, limit, context);
    if (resolvedFilters.assetServiceLogs && resolvedFilters.pagination) return resolvedFilters;

    const skip = (page - 1) * limit;
    const orderBy = resolveOrderBy(sortBy, order);
    const [assetServiceLogs, total] = await Promise.all([
      assetServiceLogRepository.findMany(resolvedFilters, skip, limit, orderBy, SERVICE_LOG_INCLUDE),
      assetServiceLogRepository.count(resolvedFilters),
    ]);

    return {
      assetServiceLogs: assetServiceLogs.map(mapAssetServiceLog),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getAssetServiceLogById = async (id, userId, ipAddress, context = {}) => {
  try {
    const resolvedId = await resolveServiceLogId(id);
    const assetServiceLog = await assetServiceLogRepository.findById(resolvedId, SERVICE_LOG_INCLUDE);

    if (!assetServiceLog || isOutsideScope(assetServiceLog, context)) {
      throw new HttpError('errors.asset_service_log.not_found', 404);
    }

    return mapAssetServiceLog(assetServiceLog);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createAssetServiceLog = async (data, userId, ipAddress, context = {}) => {
  try {
    const processedData = await resolvePayload(data, context);
    const assetServiceLog = await assetServiceLogRepository.create(processedData, SERVICE_LOG_INCLUDE);

    createAuditLog({
      user_id: userId,
      tenant_id: assetServiceLog?.asset?.tenant_id || context?.tenant_id || null,
      facility_id: assetServiceLog?.asset?.facility_id || context?.facility_id || null,
      action: 'CREATE',
      entity: 'asset_service_log',
      entity_id: assetServiceLog.id,
      diff: { after: assetServiceLog },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapAssetServiceLog(assetServiceLog);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateAssetServiceLog = async (id, data, userId, ipAddress, context = {}) => {
  try {
    const resolvedId = await resolveServiceLogId(id);
    const before = await assetServiceLogRepository.findById(resolvedId, SERVICE_LOG_INCLUDE);

    if (!before || isOutsideScope(before, context)) {
      throw new HttpError('errors.asset_service_log.not_found', 404);
    }

    const processedData = await resolvePayload(data, context);
    const assetServiceLog = await assetServiceLogRepository.update(resolvedId, processedData, SERVICE_LOG_INCLUDE);

    createAuditLog({
      user_id: userId,
      tenant_id: before?.asset?.tenant_id || context?.tenant_id || null,
      facility_id: before?.asset?.facility_id || context?.facility_id || null,
      action: 'UPDATE',
      entity: 'asset_service_log',
      entity_id: assetServiceLog.id,
      diff: { before, after: assetServiceLog },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapAssetServiceLog(assetServiceLog);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteAssetServiceLog = async (id, userId, ipAddress, context = {}) => {
  try {
    const resolvedId = await resolveServiceLogId(id);
    const before = await assetServiceLogRepository.findById(resolvedId, SERVICE_LOG_INCLUDE);

    if (!before || isOutsideScope(before, context)) {
      throw new HttpError('errors.asset_service_log.not_found', 404);
    }

    await assetServiceLogRepository.softDelete(resolvedId);

    createAuditLog({
      user_id: userId,
      tenant_id: before?.asset?.tenant_id || context?.tenant_id || null,
      facility_id: before?.asset?.facility_id || context?.facility_id || null,
      action: 'DELETE',
      entity: 'asset_service_log',
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
  listAssetServiceLogs,
  getAssetServiceLogById,
  createAssetServiceLog,
  updateAssetServiceLog,
  deleteAssetServiceLog,
};
