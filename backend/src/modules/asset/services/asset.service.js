/**
 * Asset service
 *
 * @module modules/asset/services
 * @description Business logic layer for asset operations.
 */

const assetRepository = require('@repositories/asset/asset.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveEntityId, resolveIdentifierForFilter, resolveIdentifierForPayload, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');

const ASSET_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'name',
  'asset_tag',
  'status',
]);

const ASSET_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true, name: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
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
  const field = ASSET_SORT_FIELDS.has(sortBy) ? sortBy : 'created_at';
  return { [field]: order === 'asc' ? 'asc' : 'desc' };
};

const mapAsset = (record) => {
  if (!record || typeof record !== 'object') return record;
  const id = displayId(record);

  return {
    ...record,
    id,
    human_friendly_id: id,
    display_id: id,
    tenant_id: publicRelationId(record, 'tenant', 'tenant_id'),
    tenant_label: record?.tenant?.name || null,
    facility_id: publicRelationId(record, 'facility', 'facility_id'),
    facility_label: record?.facility?.name || null,
  };
};

const resolveAssetId = (identifier, context = {}) =>
  resolveEntityId({
    model: 'asset',
    identifier,
    where: {
      ...(context?.tenant_id ? { tenant_id: context.tenant_id } : {}),
      ...(context?.facility_id ? { facility_id: context.facility_id } : {}),
    },
  });

const resolveListFilters = async (filters = {}, page = 1, limit = 20, context = {}) => {
  const repoFilters = {};

  const requestedTenant = filters.tenant_id || context?.tenant_id;
  if (requestedTenant !== undefined) {
    const tenantId = await resolveIdentifierForFilter({
      value: requestedTenant,
      model: 'tenant',
    });
    if (tenantId === null) {
      return {
        assets: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (tenantId !== undefined) repoFilters.tenant_id = tenantId;
  }

  const facilityWhere = repoFilters.tenant_id ? { tenant_id: repoFilters.tenant_id } : {};
  const requestedFacility = filters.facility_id || context?.facility_id;
  if (requestedFacility !== undefined) {
    const facilityId = await resolveIdentifierForFilter({
      value: requestedFacility,
      model: 'facility',
      where: facilityWhere,
    });
    if (facilityId === null) {
      return {
        assets: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (facilityId !== undefined) repoFilters.facility_id = facilityId;
  }

  if (filters.name) repoFilters.name = { contains: filters.name };
  if (filters.asset_tag) repoFilters.asset_tag = { contains: filters.asset_tag };
  if (filters.status) repoFilters.status = filters.status;

  if (filters.search) {
    repoFilters.OR = [
      { human_friendly_id: { contains: String(filters.search).trim().toUpperCase() } },
      { name: { contains: filters.search } },
      { asset_tag: { contains: filters.search } },
    ];
  }

  return repoFilters;
};

const resolvePayload = async (data = {}, context = {}) => {
  const payload = { ...data };

  if (hasOwn(payload, 'tenant_id')) {
    payload.tenant_id = await resolveIdentifierForPayload({
      value: payload.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
    });
  } else if (context?.tenant_id) {
    payload.tenant_id = context.tenant_id;
  }
  if (!payload.tenant_id && hasOwn(data, 'tenant_id')) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'tenant_id' }]);
  }
  if (!payload.tenant_id) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const tenantWhere = payload.tenant_id ? { tenant_id: payload.tenant_id } : {};
  if (hasOwn(payload, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      nullable: true,
      where: tenantWhere,
    });
  } else if (context?.facility_id) {
    payload.facility_id = context.facility_id;
  }

  return payload;
};

const listAssets = async (filters, page, limit, sortBy, order, userId, ipAddress, context = {}) => {
  try {
    const resolvedFilters = await resolveListFilters(filters, page, limit, context);
    if (resolvedFilters.assets && resolvedFilters.pagination) return resolvedFilters;

    const skip = (page - 1) * limit;
    const orderBy = resolveOrderBy(sortBy, order);
    const [assets, total] = await Promise.all([
      assetRepository.findMany(resolvedFilters, skip, limit, orderBy, ASSET_INCLUDE),
      assetRepository.count(resolvedFilters),
    ]);

    return {
      assets: assets.map(mapAsset),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getAssetById = async (id, userId, ipAddress, context = {}) => {
  try {
    const resolvedId = await resolveAssetId(id, context);
    const asset = await assetRepository.findById(resolvedId, ASSET_INCLUDE);

    if (!asset) {
      throw new HttpError('errors.asset.not_found', 404);
    }

    return mapAsset(asset);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createAsset = async (data, userId, ipAddress, context = {}) => {
  try {
    const processedData = await resolvePayload(data, context);
    const asset = await assetRepository.create(processedData, ASSET_INCLUDE);

    createAuditLog({
      user_id: userId,
      tenant_id: asset.tenant_id,
      facility_id: asset.facility_id,
      action: 'CREATE',
      entity: 'asset',
      entity_id: asset.id,
      diff: { after: asset },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapAsset(asset);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateAsset = async (id, data, userId, ipAddress, context = {}) => {
  try {
    const resolvedId = await resolveAssetId(id, context);
    const before = await assetRepository.findById(resolvedId, ASSET_INCLUDE);

    if (!before) {
      throw new HttpError('errors.asset.not_found', 404);
    }

    const processedData = await resolvePayload(data, { tenant_id: before.tenant_id });
    delete processedData.tenant_id;

    const asset = await assetRepository.update(resolvedId, processedData, ASSET_INCLUDE);

    createAuditLog({
      user_id: userId,
      tenant_id: before.tenant_id,
      facility_id: before.facility_id,
      action: 'UPDATE',
      entity: 'asset',
      entity_id: asset.id,
      diff: { before, after: asset },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapAsset(asset);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteAsset = async (id, userId, ipAddress, context = {}) => {
  try {
    const resolvedId = await resolveAssetId(id, context);
    const before = await assetRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.asset.not_found', 404);
    }

    await assetRepository.softDelete(resolvedId);

    createAuditLog({
      user_id: userId,
      tenant_id: before.tenant_id,
      facility_id: before.facility_id,
      action: 'DELETE',
      entity: 'asset',
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
  listAssets,
  getAssetById,
  createAsset,
  updateAsset,
  deleteAsset,
};
