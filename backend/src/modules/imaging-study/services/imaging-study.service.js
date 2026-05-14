/**
 * Imaging study service
 *
 * @module modules/imaging-study/services
 * @description Business logic layer for imaging study operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const imagingStudyRepository = require('@repositories/imaging-study/imaging-study.repository');
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
  imagingStudies: [],
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
 * List imaging studies with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Imaging studies and pagination data
 */
const listImagingStudies = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.radiology_order_id !== undefined) {
      const orderId = await resolveIdentifierForFilter({
        value: filters.radiology_order_id,
        model: 'radiology_order',
        where: { deleted_at: null },
      });
      if (orderId === null) return buildEmptyListResult(page, limit);
      if (orderId !== undefined) whereClause.radiology_order_id = orderId;
    }
    if (filters.modality) whereClause.modality = filters.modality;
    if (filters.performed_at) whereClause.performed_at = filters.performed_at;

    const [imagingStudies, total] = await Promise.all([
      imagingStudyRepository.findMany(whereClause, skip, limit, orderBy),
      imagingStudyRepository.count(whereClause)
    ]);

    return {
      imagingStudies,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get imaging study by ID
 *
 * @param {string} id - Imaging study ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Imaging study data
 */
const getImagingStudyById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('imaging_study', id);
    const imagingStudy = await imagingStudyRepository.findById(resolvedId);

    if (!imagingStudy) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    return imagingStudy;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new imaging study
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Imaging study data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created imaging study
 */
const createImagingStudy = async (data, userId, ipAddress) => {
  try {
    const normalizedData = {
      ...data,
      radiology_order_id: await resolveIdentifierForPayload({
        value: data.radiology_order_id,
        field: 'radiology_order_id',
        model: 'radiology_order',
        where: { deleted_at: null },
      }),
    };
    const imagingStudy = await imagingStudyRepository.create(normalizedData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'imaging_study',
      entity_id: imagingStudy.id,
      diff: { after: imagingStudy },
      ip_address: ipAddress
    }).catch(() => {});

    return imagingStudy;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update imaging study
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Imaging study ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated imaging study
 */
const updateImagingStudy = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('imaging_study', id);

    // Get current state for audit
    const before = await imagingStudyRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'radiology_order_id')) {
      payload.radiology_order_id = await resolveIdentifierForPayload({
        value: payload.radiology_order_id,
        field: 'radiology_order_id',
        model: 'radiology_order',
        where: { deleted_at: null },
      });
    }

    const imagingStudy = await imagingStudyRepository.update(resolvedId, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'imaging_study',
      entity_id: imagingStudy.id,
      diff: { before, after: imagingStudy },
      ip_address: ipAddress
    }).catch(() => {});

    return imagingStudy;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete imaging study (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Imaging study ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteImagingStudy = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('imaging_study', id);

    // Get current state for audit
    const before = await imagingStudyRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    await imagingStudyRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'imaging_study',
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
  listImagingStudies,
  getImagingStudyById,
  createImagingStudy,
  updateImagingStudy,
  deleteImagingStudy
};
