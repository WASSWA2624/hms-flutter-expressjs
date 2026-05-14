/**
 * OAuth Account service
 *
 * @module modules/oauth-account/services
 * @description Business logic layer for OAuth account operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const oauthAccountRepository = require('@repositories/oauth-account/oauth-account.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List OAuth accounts with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} OAuth accounts and pagination data
 */
const listOAuthAccounts = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.user_id) whereClause.user_id = filters.user_id;
    if (filters.provider) whereClause.provider = filters.provider;

    const [oauthAccounts, total] = await Promise.all([
      oauthAccountRepository.findMany(whereClause, skip, limit, orderBy),
      oauthAccountRepository.count(whereClause)
    ]);

    return {
      oauth_accounts: oauthAccounts,
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
 * Get OAuth account by ID
 *
 * @param {string} id - OAuth Account ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} OAuth account data
 */
const getOAuthAccountById = async (id, userId, ipAddress) => {
  try {
    const oauthAccount = await oauthAccountRepository.findById(id);

    if (!oauthAccount) {
      throw new HttpError('errors.oauth_account.not_found', 404);
    }

    return oauthAccount;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get OAuth accounts by user ID
 *
 * @param {string} userId - User ID
 * @param {string} requestUserId - Requesting user ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Array>} OAuth accounts for the user
 */
const getOAuthAccountsByUserId = async (userId, requestUserId, ipAddress) => {
  try {
    const oauthAccounts = await oauthAccountRepository.findMany({ user_id: userId });
    return oauthAccounts;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new OAuth account
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - OAuth account data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created OAuth account
 */
const createOAuthAccount = async (data, userId, ipAddress) => {
  try {
    const oauthAccount = await oauthAccountRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'oauth_account',
      entity_id: oauthAccount.id,
      diff: { after: oauthAccount },
      ip_address: ipAddress
    }).catch(() => {});

    return oauthAccount;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update OAuth account
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - OAuth Account ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated OAuth account
 */
const updateOAuthAccount = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await oauthAccountRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.oauth_account.not_found', 404);
    }

    const oauthAccount = await oauthAccountRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'oauth_account',
      entity_id: oauthAccount.id,
      diff: { before, after: oauthAccount },
      ip_address: ipAddress
    }).catch(() => {});

    return oauthAccount;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete OAuth account (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - OAuth Account ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteOAuthAccount = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await oauthAccountRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.oauth_account.not_found', 404);
    }

    await oauthAccountRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'oauth_account',
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
  listOAuthAccounts,
  getOAuthAccountById,
  getOAuthAccountsByUserId,
  createOAuthAccount,
  updateOAuthAccount,
  deleteOAuthAccount
};
