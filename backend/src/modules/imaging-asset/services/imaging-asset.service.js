/**
 * Imaging asset service
 *
 * @module modules/imaging-asset/services
 * @description Business logic layer for imaging asset operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const imagingAssetRepository = require('@repositories/imaging-asset/imaging-asset.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const buildEmptyListResult = (page, limit) => ({
  imagingAssets: [],
  pagination: buildPagination(page, limit, 0),
});

const resolveResourceId = async (model, identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return normalized;

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where: { deleted_at: null },
  });

  return resolved || normalized;
};

/**
 * List imaging assets with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Imaging assets and pagination data
 */
const listImagingAssets = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.imaging_study_id !== undefined) {
      const studyId = await resolveIdentifierForFilter({
        value: filters.imaging_study_id,
        model: 'imaging_study',
        where: { deleted_at: null },
      });
      if (studyId === null) return buildEmptyListResult(page, limit);
      if (studyId !== undefined) whereClause.imaging_study_id = studyId;
    }
    if (filters.content_type) whereClause.content_type = { contains: filters.content_type };

    const [imagingAssets, total] = await Promise.all([
      imagingAssetRepository.findMany(whereClause, skip, limit, orderBy),
      imagingAssetRepository.count(whereClause)
    ]);

    return {
      imagingAssets,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get imaging asset by ID
 *
 * @param {string} id - Imaging asset ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Imaging asset data
 */
const getImagingAssetById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('imaging_asset', id);
    const imagingAsset = await imagingAssetRepository.findById(resolvedId);

    if (!imagingAsset) {
      throw new HttpError('errors.imaging_asset.not_found', 404);
    }

    return imagingAsset;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new imaging asset
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Imaging asset data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created imaging asset
 */
const createImagingAsset = async (data, userId, ipAddress) => {
  try {
    const normalizedData = {
      ...data,
      imaging_study_id: await resolveIdentifierForPayload({
        value: data.imaging_study_id,
        field: 'imaging_study_id',
        model: 'imaging_study',
        where: { deleted_at: null },
      }),
    };
    const imagingAsset = await imagingAssetRepository.create(normalizedData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'imaging_asset',
      entity_id: imagingAsset.id,
      diff: { after: imagingAsset },
      ip_address: ipAddress
    }).catch(() => {});

    return imagingAsset;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update imaging asset
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Imaging asset ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated imaging asset
 */
const updateImagingAsset = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('imaging_asset', id);

    // Get current state for audit
    const before = await imagingAssetRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.imaging_asset.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'imaging_study_id')) {
      payload.imaging_study_id = await resolveIdentifierForPayload({
        value: payload.imaging_study_id,
        field: 'imaging_study_id',
        model: 'imaging_study',
        where: { deleted_at: null },
      });
    }

    const imagingAsset = await imagingAssetRepository.update(resolvedId, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'imaging_asset',
      entity_id: imagingAsset.id,
      diff: { before, after: imagingAsset },
      ip_address: ipAddress
    }).catch(() => {});

    return imagingAsset;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete imaging asset (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Imaging asset ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteImagingAsset = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('imaging_asset', id);

    // Get current state for audit
    const before = await imagingAssetRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.imaging_asset.not_found', 404);
    }

    await imagingAssetRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'imaging_asset',
      entity_id: resolvedId,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listImagingAssets,
  getImagingAssetById,
  createImagingAsset,
  updateImagingAsset,
  deleteImagingAsset
};
