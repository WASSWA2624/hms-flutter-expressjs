/**
 * Radiology Result service
 *
 * @module modules/radiology-result/services
 * @description Business logic layer for radiology result operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const radiologyResultRepository = require('@repositories/radiology-result/radiology-result.repository');
const {
  RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE,
} = require('@services/radiology-workspace/radiology.shared');
const {
  mapRadiologyResultRecord,
} = require('@services/radiology-workspace/radiology.serializer');
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
  radiology_results: [],
  pagination: buildPagination(page, limit, 0),
});

const serializeRadiologyResult = (record) =>
  mapRadiologyResultRecord(record) || record;

const fetchSerializedRadiologyResultById = async (id) => {
  const record = await radiologyResultRepository.findById(
    id,
    RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
  );
  return serializeRadiologyResult(record);
};

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
 * List radiology results with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology results and pagination data
 */
const listRadiologyResults = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
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
    if (filters.status) whereClause.status = filters.status;
    
    // Search filter (searches in report_text)
    if (filters.search) {
      whereClause.report_text = { contains: filters.search };
    }

    const [radiologyResults, total] = await Promise.all([
      radiologyResultRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      ),
      radiologyResultRepository.count(whereClause)
    ]);

    return {
      radiology_results: radiologyResults.map(serializeRadiologyResult).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get radiology result by ID
 *
 * @param {string} id - Radiology Result ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology result data
 */
const getRadiologyResultById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_result', id);
    const radiologyResult = await radiologyResultRepository.findById(
      resolvedId,
      RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
    );

    if (!radiologyResult) {
      throw new HttpError('errors.radiology_result.not_found', 404);
    }

    return serializeRadiologyResult(radiologyResult);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new radiology result
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Radiology Result data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created radiology result
 */
const createRadiologyResult = async (data, userId, ipAddress) => {
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

    const radiologyResult = await radiologyResultRepository.create(normalizedData);
    const serializedRadiologyResult = await fetchSerializedRadiologyResultById(
      radiologyResult.id
    );

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'radiology_result',
      entity_id: radiologyResult.id,
      diff: { after: radiologyResult },
      ip_address: ipAddress
    }).catch(() => {});

    return serializedRadiologyResult;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update radiology result
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology Result ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated radiology result
 */
const updateRadiologyResult = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_result', id);

    // Get current state for audit
    const before = await radiologyResultRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_result.not_found', 404);
    }

    const normalizedData = {
      ...data,
    };
    if (Object.prototype.hasOwnProperty.call(data, 'radiology_order_id')) {
      normalizedData.radiology_order_id = await resolveIdentifierForPayload({
        value: data.radiology_order_id,
        field: 'radiology_order_id',
        model: 'radiology_order',
        where: { deleted_at: null },
      });
    }

    const radiologyResult = await radiologyResultRepository.update(resolvedId, normalizedData);
    const serializedRadiologyResult = await fetchSerializedRadiologyResultById(
      radiologyResult.id
    );

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'radiology_result',
      entity_id: radiologyResult.id,
      diff: { before, after: radiologyResult },
      ip_address: ipAddress
    }).catch(() => {});

    return serializedRadiologyResult;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete radiology result (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology Result ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRadiologyResult = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_result', id);

    // Get current state for audit
    const before = await radiologyResultRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_result.not_found', 404);
    }

    await radiologyResultRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'radiology_result',
      entity_id: resolvedId,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Sign off radiology result
 *
 * @param {string} id - Radiology Result ID
 * @param {Object} data - Sign-off payload
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated radiology result
 */
const signOffRadiologyResult = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_result', id);
    const before = await radiologyResultRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_result.not_found', 404);
    }

    if (before.status === 'FINAL') {
      throw new HttpError('errors.radiology_result.already_signed_off', 400);
    }

    const updateData = {
      status: 'FINAL',
      reported_at: data.reported_at ? new Date(data.reported_at) : new Date()
    };

    const radiologyResult = await radiologyResultRepository.update(resolvedId, updateData);
    const serializedRadiologyResult = await fetchSerializedRadiologyResultById(
      radiologyResult.id
    );

    createAuditLog({
      user_id: userId,
      action: 'SIGN_OFF',
      entity: 'radiology_result',
      entity_id: radiologyResult.id,
      diff: {
        before,
        after: radiologyResult,
        metadata: {
          notes: data.notes || null
        }
      },
      ip_address: ipAddress
    }).catch(() => {});

    return serializedRadiologyResult;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listRadiologyResults,
  getRadiologyResultById,
  createRadiologyResult,
  updateRadiologyResult,
  deleteRadiologyResult,
  signOffRadiologyResult
};
