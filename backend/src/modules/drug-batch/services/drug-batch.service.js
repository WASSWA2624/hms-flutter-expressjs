/**
 * Drug batch service
 *
 * @module modules/drug-batch/services
 * @description Business logic layer for drug batch operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const drugBatchRepository = require('@repositories/drug-batch/drug-batch.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List drug batches with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Drug batches and pagination data
 */
const listDrugBatches = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.drug_id) whereClause.drug_id = filters.drug_id;
    if (filters.batch_number) whereClause.batch_number = { contains: filters.batch_number };
    
    // Handle expired filter
    if (filters.expired !== undefined) {
      if (filters.expired) {
        whereClause.expiry_date = { lt: new Date() };
      } else {
        whereClause.expiry_date = { gte: new Date() };
      }
    }
    
    // Search filter (searches in batch_number)
    if (filters.search) {
      whereClause.batch_number = { contains: filters.search };
    }

    const [drugBatches, total] = await Promise.all([
      drugBatchRepository.findMany(whereClause, skip, limit, orderBy),
      drugBatchRepository.count(whereClause)
    ]);

    return {
      drugBatches,
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
 * Get drug batch by ID
 *
 * @param {string} id - Drug batch ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Drug batch data
 */
const getDrugBatchById = async (id, userId, ipAddress) => {
  try {
    const drugBatch = await drugBatchRepository.findById(id);

    if (!drugBatch) {
      throw new HttpError('errors.drug_batch.not_found', 404);
    }

    return drugBatch;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new drug batch
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Drug batch data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created drug batch
 */
const createDrugBatch = async (data, userId, ipAddress) => {
  try {
    const drugBatch = await drugBatchRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'drug_batch',
      entity_id: drugBatch.id,
      diff: { after: drugBatch },
      ip_address: ipAddress
    }).catch(() => {});

    return drugBatch;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update drug batch
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Drug batch ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated drug batch
 */
const updateDrugBatch = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await drugBatchRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.drug_batch.not_found', 404);
    }

    const drugBatch = await drugBatchRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'drug_batch',
      entity_id: drugBatch.id,
      diff: { before, after: drugBatch },
      ip_address: ipAddress
    }).catch(() => {});

    return drugBatch;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete drug batch (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Drug batch ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteDrugBatch = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await drugBatchRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.drug_batch.not_found', 404);
    }

    await drugBatchRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'drug_batch',
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
  listDrugBatches,
  getDrugBatchById,
  createDrugBatch,
  updateDrugBatch,
  deleteDrugBatch
};
