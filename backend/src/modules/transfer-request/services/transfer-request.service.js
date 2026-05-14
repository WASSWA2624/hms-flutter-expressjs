/**
 * Transfer request service
 *
 * @module modules/transfer-request/services
 * @description Business logic layer for transfer request operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const transferRequestRepository = require('@repositories/transfer-request/transfer-request.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List transfer requests with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Transfer requests and pagination data
 */
const listTransferRequests = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.admission_id) whereClause.admission_id = filters.admission_id;
    if (filters.from_ward_id) whereClause.from_ward_id = filters.from_ward_id;
    if (filters.to_ward_id) whereClause.to_ward_id = filters.to_ward_id;
    if (filters.status) whereClause.status = filters.status;
    
    // Search filter (could search across related admission data if needed)
    if (filters.search) {
      // For now, we'll keep it simple. In production, you might want to search related entities
      // This can be extended based on business requirements
    }

    const [transferRequests, total] = await Promise.all([
      transferRequestRepository.findMany(whereClause, skip, limit, orderBy),
      transferRequestRepository.count(whereClause)
    ]);

    return {
      transferRequests,
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
 * Get transfer request by ID
 *
 * @param {string} id - Transfer request ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Transfer request data
 */
const getTransferRequestById = async (id, userId, ipAddress) => {
  try {
    const transferRequest = await transferRequestRepository.findById(id);

    if (!transferRequest) {
      throw new HttpError('errors.transfer_request.not_found', 404);
    }

    return transferRequest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new transfer request
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Transfer request data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created transfer request
 */
const createTransferRequest = async (data, userId, ipAddress) => {
  try {
    // Set default status if not provided
    const transferRequestData = {
      ...data,
      status: data.status || 'REQUESTED',
      requested_at: data.requested_at || new Date().toISOString()
    };

    const transferRequest = await transferRequestRepository.create(transferRequestData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'transfer_request',
      entity_id: transferRequest.id,
      diff: { after: transferRequest },
      ip_address: ipAddress
    }).catch(() => {});

    return transferRequest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update transfer request
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Transfer request ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated transfer request
 */
const updateTransferRequest = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await transferRequestRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.transfer_request.not_found', 404);
    }

    const transferRequest = await transferRequestRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'transfer_request',
      entity_id: transferRequest.id,
      diff: { before, after: transferRequest },
      ip_address: ipAddress
    }).catch(() => {});

    return transferRequest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete transfer request (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Transfer request ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteTransferRequest = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await transferRequestRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.transfer_request.not_found', 404);
    }

    await transferRequestRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'transfer_request',
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
  listTransferRequests,
  getTransferRequestById,
  createTransferRequest,
  updateTransferRequest,
  deleteTransferRequest
};
