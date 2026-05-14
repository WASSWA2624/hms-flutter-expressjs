/**
 * Radiology test service
 *
 * @module modules/radiology-test/services
 * @description Business logic layer for radiology test operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const radiologyTestRepository = require('@repositories/radiology-test/radiology-test.repository');
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
  radiologyTests: [],
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
 * List radiology tests with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology tests and pagination data
 */
const listRadiologyTests = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }
    if (filters.modality) whereClause.modality = filters.modality;
    if (filters.code) whereClause.code = { contains: filters.code };
    if (filters.name) whereClause.name = { contains: filters.name };
    
    // Search filter (searches in name, code)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { code: { contains: filters.search } }
      ];
    }

    const [radiologyTests, total] = await Promise.all([
      radiologyTestRepository.findMany(whereClause, skip, limit, orderBy),
      radiologyTestRepository.count(whereClause)
    ]);

    return {
      radiologyTests,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get radiology test by ID
 *
 * @param {string} id - Radiology test ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology test data
 */
const getRadiologyTestById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_test', id);
    const radiologyTest = await radiologyTestRepository.findById(resolvedId);

    if (!radiologyTest) {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }

    return radiologyTest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new radiology test
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Radiology test data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created radiology test
 */
const createRadiologyTest = async (data, userId, ipAddress) => {
  try {
    const normalizedData = {
      ...data,
      tenant_id: await resolveIdentifierForPayload({
        value: data.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      }),
    };
    const radiologyTest = await radiologyTestRepository.create(normalizedData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'radiology_test',
      entity_id: radiologyTest.id,
      diff: { after: radiologyTest },
      ip_address: ipAddress
    }).catch(() => {});

    return radiologyTest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update radiology test
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology test ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated radiology test
 */
const updateRadiologyTest = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_test', id);

    // Get current state for audit
    const before = await radiologyTestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id')) {
      payload.tenant_id = await resolveIdentifierForPayload({
        value: payload.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      });
    }

    const radiologyTest = await radiologyTestRepository.update(resolvedId, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'radiology_test',
      entity_id: radiologyTest.id,
      diff: { before, after: radiologyTest },
      ip_address: ipAddress
    }).catch(() => {});

    return radiologyTest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete radiology test (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology test ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRadiologyTest = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_test', id);

    // Get current state for audit
    const before = await radiologyTestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }

    await radiologyTestRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'radiology_test',
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
  listRadiologyTests,
  getRadiologyTestById,
  createRadiologyTest,
  updateRadiologyTest,
  deleteRadiologyTest
};
