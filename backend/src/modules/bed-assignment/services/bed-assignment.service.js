/**
 * Bed Assignment service
 *
 * @module modules/bed-assignment/services
 * @description Business logic layer for bed assignment operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const bedAssignmentRepository = require('@repositories/bed-assignment/bed-assignment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List bed assignments with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Bed assignments and pagination data
 */
const listBedAssignments = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};
    
    if (filters.admission_id) whereClause.admission_id = filters.admission_id;
    if (filters.bed_id) whereClause.bed_id = filters.bed_id;

    const [bedAssignments, total] = await Promise.all([
      bedAssignmentRepository.findMany(whereClause, skip, limit, orderBy),
      bedAssignmentRepository.count(whereClause)
    ]);

    return {
      bedAssignments,
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
 * Get bed assignment by ID
 *
 * @param {string} id - Bed Assignment ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Bed assignment data
 */
const getBedAssignmentById = async (id, userId, ipAddress) => {
  try {
    const bedAssignment = await bedAssignmentRepository.findById(id);

    if (!bedAssignment) {
      throw new HttpError('errors.bed_assignment.not_found', 404);
    }

    return bedAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new bed assignment
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Bed Assignment data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created bed assignment
 */
const createBedAssignment = async (data, userId, ipAddress) => {
  try {
    const bedAssignment = await bedAssignmentRepository.create(data);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'bed_assignment',
      entity_id: bedAssignment.id,
      diff: { after: bedAssignment },
      ip_address: ipAddress
    }).catch(() => {});

    return bedAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update bed assignment
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Bed Assignment ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated bed assignment
 */
const updateBedAssignment = async (id, data, userId, ipAddress) => {
  try {
    const before = await bedAssignmentRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.bed_assignment.not_found', 404);
    }

    const bedAssignment = await bedAssignmentRepository.update(id, data);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'bed_assignment',
      entity_id: bedAssignment.id,
      diff: { before, after: bedAssignment },
      ip_address: ipAddress
    }).catch(() => {});

    return bedAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete bed assignment (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Bed Assignment ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteBedAssignment = async (id, userId, ipAddress) => {
  try {
    const before = await bedAssignmentRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.bed_assignment.not_found', 404);
    }

    await bedAssignmentRepository.softDelete(id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'bed_assignment',
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
  listBedAssignments,
  getBedAssignmentById,
  createBedAssignment,
  updateBedAssignment,
  deleteBedAssignment
};
