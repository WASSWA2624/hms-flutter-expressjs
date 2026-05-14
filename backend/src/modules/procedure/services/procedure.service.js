/**
 * Procedure service
 *
 * @module modules/procedure/services
 * @description Business logic layer for procedure operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const procedureRepository = require('@repositories/procedure/procedure.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List procedures with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Procedures and pagination data
 */
const listProcedures = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.encounter_id) whereClause.encounter_id = filters.encounter_id;
    if (filters.code) whereClause.code = { contains: filters.code };

    const [procedures, total] = await Promise.all([
      procedureRepository.findMany(whereClause, skip, limit, orderBy),
      procedureRepository.count(whereClause)
    ]);

    return {
      procedures,
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
 * Get procedure by ID
 *
 * @param {string} id - Procedure ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Procedure data
 */
const getProcedureById = async (id, userId, ipAddress) => {
  try {
    const procedure = await procedureRepository.findById(id);

    if (!procedure) {
      throw new HttpError('errors.procedure.not_found', 404);
    }

    return procedure;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new procedure
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Procedure data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created procedure
 */
const createProcedure = async (data, userId, ipAddress) => {
  try {
    const procedure = await procedureRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'procedure',
      entity_id: procedure.id,
      diff: { after: procedure },
      ip_address: ipAddress
    }).catch(() => {});

    return procedure;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update procedure
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Procedure ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated procedure
 */
const updateProcedure = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await procedureRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.procedure.not_found', 404);
    }

    const procedure = await procedureRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'procedure',
      entity_id: procedure.id,
      diff: { before, after: procedure },
      ip_address: ipAddress
    }).catch(() => {});

    return procedure;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete procedure (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Procedure ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteProcedure = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await procedureRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.procedure.not_found', 404);
    }

    await procedureRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'procedure',
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
  listProcedures,
  getProcedureById,
  createProcedure,
  updateProcedure,
  deleteProcedure
};
