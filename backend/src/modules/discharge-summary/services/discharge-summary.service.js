/**
 * Discharge summary service
 *
 * @module modules/discharge-summary/services
 * @description Business logic layer for discharge summary operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const dischargeSummaryRepository = require('@repositories/discharge-summary/discharge-summary.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List discharge summaries with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Discharge summaries and pagination data
 */
const listDischargeSummaries = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.admission_id) whereClause.admission_id = filters.admission_id;
    if (filters.status) whereClause.status = filters.status;

    const [dischargeSummaries, total] = await Promise.all([
      dischargeSummaryRepository.findMany(whereClause, skip, limit, orderBy),
      dischargeSummaryRepository.count(whereClause)
    ]);

    return {
      dischargeSummaries,
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
 * Get discharge summary by ID
 *
 * @param {string} id - Discharge summary ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Discharge summary data
 */
const getDischargeSummaryById = async (id, userId, ipAddress) => {
  try {
    const dischargeSummary = await dischargeSummaryRepository.findById(id);

    if (!dischargeSummary) {
      throw new HttpError('errors.discharge_summary.not_found', 404);
    }

    return dischargeSummary;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new discharge summary
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Discharge summary data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created discharge summary
 */
const createDischargeSummary = async (data, userId, ipAddress) => {
  try {
    const dischargeSummary = await dischargeSummaryRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'discharge_summary',
      entity_id: dischargeSummary.id,
      diff: { after: dischargeSummary },
      ip_address: ipAddress
    }).catch(() => {});

    return dischargeSummary;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update discharge summary
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Discharge summary ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated discharge summary
 */
const updateDischargeSummary = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await dischargeSummaryRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.discharge_summary.not_found', 404);
    }

    const dischargeSummary = await dischargeSummaryRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'discharge_summary',
      entity_id: dischargeSummary.id,
      diff: { before, after: dischargeSummary },
      ip_address: ipAddress
    }).catch(() => {});

    return dischargeSummary;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete discharge summary (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Discharge summary ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteDischargeSummary = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await dischargeSummaryRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.discharge_summary.not_found', 404);
    }

    await dischargeSummaryRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'discharge_summary',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Finalize discharge summary (workflow action)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Discharge summary ID
 * @param {Object} data - Finalization data
 * @param {string} [data.discharged_at] - Final discharged timestamp
 * @param {string} [data.notes] - Finalization notes
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated discharge summary
 */
const finalizeDischargeSummary = async (id, data = {}, userId, ipAddress) => {
  try {
    const before = await dischargeSummaryRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.discharge_summary.not_found', 404);
    }

    if (before.status === 'CANCELLED') {
      throw new HttpError('errors.discharge_summary.cannot_finalize_cancelled', 400);
    }

    const updateData = {
      status: 'COMPLETED',
      discharged_at: data.discharged_at || new Date().toISOString()
    };

    const dischargeSummary = await dischargeSummaryRepository.update(id, updateData);

    createAuditLog({
      user_id: userId,
      action: 'FINALIZE',
      entity: 'discharge_summary',
      entity_id: dischargeSummary.id,
      diff: {
        before,
        after: dischargeSummary,
        metadata: {
          notes: data.notes || null
        }
      },
      ip_address: ipAddress
    }).catch(() => {});

    return dischargeSummary;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listDischargeSummaries,
  getDischargeSummaryById,
  createDischargeSummary,
  updateDischargeSummary,
  deleteDischargeSummary,
  finalizeDischargeSummary
};
