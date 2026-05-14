/**
 * Ward Round service
 *
 * @module modules/ward-round/services
 * @description Business logic layer for ward round operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const wardRoundRepository = require('@repositories/ward-round/ward-round.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List ward rounds with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Ward rounds and pagination data
 */
const listWardRounds = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};
    
    if (filters.admission_id) whereClause.admission_id = filters.admission_id;

    const [wardRounds, total] = await Promise.all([
      wardRoundRepository.findMany(whereClause, skip, limit, orderBy),
      wardRoundRepository.count(whereClause)
    ]);

    return {
      wardRounds,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get ward round by ID
 *
 * @param {string} id - Ward Round ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Ward round data
 */
const getWardRoundById = async (id, userId, ipAddress) => {
  try {
    const wardRound = await wardRoundRepository.findById(id);

    if (!wardRound) {
      throw new HttpError('errors.ward_round.not_found', 404);
    }

    return wardRound;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new ward round
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Ward Round data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created ward round
 */
const createWardRound = async (data, userId, ipAddress) => {
  try {
    const wardRound = await wardRoundRepository.create(data);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'ward_round',
      entity_id: wardRound.id,
      diff: { after: wardRound },
      ip_address: ipAddress
    }).catch(() => {});

    return wardRound;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update ward round
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Ward Round ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated ward round
 */
const updateWardRound = async (id, data, userId, ipAddress) => {
  try {
    const before = await wardRoundRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.ward_round.not_found', 404);
    }

    const wardRound = await wardRoundRepository.update(id, data);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'ward_round',
      entity_id: wardRound.id,
      diff: { before, after: wardRound },
      ip_address: ipAddress
    }).catch(() => {});

    return wardRound;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete ward round (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Ward Round ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteWardRound = async (id, userId, ipAddress) => {
  try {
    const before = await wardRoundRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.ward_round.not_found', 404);
    }

    await wardRoundRepository.softDelete(id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'ward_round',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listWardRounds,
  getWardRoundById,
  createWardRound,
  updateWardRound,
  deleteWardRound
};
