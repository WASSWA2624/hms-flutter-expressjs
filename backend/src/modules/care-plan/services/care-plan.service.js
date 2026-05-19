/**
 * Care Plan service
 *
 * @module modules/care-plan/services
 * @description Business logic layer for care plan operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const carePlanRepository = require('@repositories/care-plan/care-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit),
  hasNextPage: page < Math.ceil(total / limit),
  hasPreviousPage: page > 1
});

const buildEmptyListResult = (page, limit) => ({
  carePlans: [],
  pagination: buildPagination(page, limit, 0)
});

const resolveCarePlanId = (id) =>
  resolveIdentifierForPayload({
    value: id,
    field: 'id',
    model: 'care_plan',
    where: { deleted_at: null },
  });

const resolveCarePlanPayload = async (input = {}) => {
  const payload = { ...input };
  if (Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
    payload.encounter_id = await resolveIdentifierForPayload({
      value: payload.encounter_id,
      field: 'encounter_id',
      model: 'encounter',
      where: { deleted_at: null },
    });
  }
  return payload;
};

/**
 * List care plans with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Care plans and pagination data
 */
const listCarePlans = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};

    if (filters.encounter_id) {
      const encounterId = await resolveIdentifierForFilter({
        value: filters.encounter_id,
        model: 'encounter',
        where: { deleted_at: null },
      });
      if (encounterId === null) return buildEmptyListResult(page, limit);
      if (encounterId !== undefined) whereClause.encounter_id = encounterId;
    }
    if (filters.start_date) whereClause.start_date = { gte: new Date(filters.start_date) };
    if (filters.end_date) whereClause.end_date = { lte: new Date(filters.end_date) };

    const [carePlans, total] = await Promise.all([
      carePlanRepository.findMany(whereClause, skip, limit, orderBy),
      carePlanRepository.count(whereClause)
    ]);

    return {
      carePlans,
      pagination: buildPagination(page, limit, total)
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get care plan by ID
 *
 * @param {string} id - Care plan ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Care plan data
 */
const getCarePlanById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveCarePlanId(id);
    const carePlan = await carePlanRepository.findById(resolvedId);

    if (!carePlan) {
      throw new HttpError('errors.care_plan.not_found', 404);
    }

    return carePlan;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new care plan
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Care plan data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created care plan
 */
const createCarePlan = async (data, userId, ipAddress) => {
  try {
    const resolvedPayload = await resolveCarePlanPayload(data);
    const carePlan = await carePlanRepository.create(resolvedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'care_plan',
      entity_id: carePlan.id,
      diff: { after: carePlan },
      ip_address: ipAddress
    }).catch(() => {});

    return carePlan;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update care plan
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Care plan ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated care plan
 */
const updateCarePlan = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const resolvedId = await resolveCarePlanId(id);
    const before = await carePlanRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.care_plan.not_found', 404);
    }

    const resolvedPayload = await resolveCarePlanPayload(data);
    const carePlan = await carePlanRepository.update(resolvedId, resolvedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'care_plan',
      entity_id: carePlan.id,
      diff: { before, after: carePlan },
      ip_address: ipAddress
    }).catch(() => {});

    return carePlan;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete care plan (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Care plan ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteCarePlan = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const resolvedId = await resolveCarePlanId(id);
    const before = await carePlanRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.care_plan.not_found', 404);
    }

    await carePlanRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'care_plan',
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
  listCarePlans,
  getCarePlanById,
  createCarePlan,
  updateCarePlan,
  deleteCarePlan
};
