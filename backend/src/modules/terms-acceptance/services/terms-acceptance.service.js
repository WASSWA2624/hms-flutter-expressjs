/**
 * Terms acceptance service
 *
 * @module modules/terms-acceptance/services
 * @description Business logic layer for terms acceptance operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 * Note: Terms acceptance has no update operation per API spec
 */

const termsAcceptanceRepository = require('@repositories/terms-acceptance/terms-acceptance.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List terms acceptances with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Terms acceptances and pagination data
 */
const listTermsAcceptances = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.user_id) whereClause.user_id = filters.user_id;
    if (filters.version_label) whereClause.version_label = filters.version_label;

    const [termsAcceptances, total] = await Promise.all([
      termsAcceptanceRepository.findMany(whereClause, skip, limit, orderBy),
      termsAcceptanceRepository.count(whereClause)
    ]);

    return {
      termsAcceptances,
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
 * Get terms acceptance by ID
 *
 * @param {string} id - Terms acceptance ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Terms acceptance data
 */
const getTermsAcceptanceById = async (id, userId, ipAddress) => {
  try {
    const termsAcceptance = await termsAcceptanceRepository.findById(id);

    if (!termsAcceptance) {
      throw new HttpError('errors.terms_acceptance.not_found', 404);
    }

    return termsAcceptance;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new terms acceptance
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Terms acceptance data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created terms acceptance
 */
const createTermsAcceptance = async (data, userId, ipAddress) => {
  try {
    const termsAcceptance = await termsAcceptanceRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'terms_acceptance',
      entity_id: termsAcceptance.id,
      diff: { after: termsAcceptance },
      ip_address: ipAddress
    }).catch(() => {});

    return termsAcceptance;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete terms acceptance (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Terms acceptance ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteTermsAcceptance = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await termsAcceptanceRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.terms_acceptance.not_found', 404);
    }

    await termsAcceptanceRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'terms_acceptance',
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
  listTermsAcceptances,
  getTermsAcceptanceById,
  createTermsAcceptance,
  deleteTermsAcceptance
};
