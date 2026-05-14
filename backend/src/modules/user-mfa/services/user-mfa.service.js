/**
 * User MFA service
 *
 * @module modules/user-mfa/services
 * @description Business logic layer for user MFA operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const userMfaRepository = require('@repositories/user-mfa/user-mfa.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { verifyUserMfaCode: verifyEncryptedUserMfaCode } = require('@lib/auth/mfa');

/**
 * List user MFAs with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User MFAs and pagination data
 */
const listUserMfas = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.user_id) whereClause.user_id = filters.user_id;
    if (filters.channel) whereClause.channel = filters.channel;
    if (filters.is_enabled !== undefined) whereClause.is_enabled = filters.is_enabled;

    const [userMfas, total] = await Promise.all([
      userMfaRepository.findMany(whereClause, skip, limit, orderBy),
      userMfaRepository.count(whereClause)
    ]);

    return {
      user_mfas: userMfas,
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
 * Get user MFA by ID
 *
 * @param {string} id - User MFA ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User MFA data
 */
const getUserMfaById = async (id, userId, ipAddress) => {
  try {
    const userMfa = await userMfaRepository.findById(id);

    if (!userMfa) {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }

    return userMfa;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get user MFAs by user ID
 *
 * @param {string} targetUserId - User ID to get MFAs for
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Array>} User MFAs
 */
const getUserMfasByUserId = async (targetUserId, userId, ipAddress) => {
  try {
    const userMfas = await userMfaRepository.findMany({ user_id: targetUserId });
    return userMfas;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user MFA
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - User MFA data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created user MFA
 */
const createUserMfa = async (data, userId, ipAddress) => {
  try {
    const userMfa = await userMfaRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'user_mfa',
      entity_id: userMfa.id,
      diff: { after: userMfa },
      ip_address: ipAddress
    }).catch(() => {});

    return userMfa;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user MFA
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User MFA ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user MFA
 */
const updateUserMfa = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userMfaRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }

    const userMfa = await userMfaRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'user_mfa',
      entity_id: userMfa.id,
      diff: { before, after: userMfa },
      ip_address: ipAddress
    }).catch(() => {});

    return userMfa;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete user MFA (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User MFA ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteUserMfa = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userMfaRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }

    await userMfaRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'user_mfa',
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
 * Verify MFA code
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User MFA ID
 * @param {string} code - MFA code to verify
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Verification result
 */
const verifyMfaCode = async (id, code, userId, ipAddress) => {
  try {
    const userMfa = await userMfaRepository.findById(id);

    if (!userMfa) {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }

    if (!userMfa.is_enabled) {
      throw new HttpError('errors.user_mfa.disabled', 400);
    }

    const isValid = verifyEncryptedUserMfaCode(userMfa, code);

    if (!isValid) {
      createAuditLog({
        user_id: userId,
        action: 'VERIFY_MFA',
        entity: 'user_mfa',
        entity_id: id,
        diff: {
          verification_result: 'FAILURE',
          channel: userMfa.channel
        },
        ip_address: ipAddress
      }).catch(() => {});
      throw new HttpError('errors.user_mfa.invalid_code', 401);
    }

    await userMfaRepository.update(id, { last_used_at: new Date() });

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'VERIFY_MFA',
      entity: 'user_mfa',
      entity_id: id,
      diff: { 
        verification_result: isValid ? 'SUCCESS' : 'FAILURE',
        channel: userMfa.channel 
      },
      ip_address: ipAddress
    }).catch(() => {});

    return { verified: isValid };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Enable MFA
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User MFA ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user MFA
 */
const enableMfa = async (id, userId, ipAddress) => {
  try {
    const before = await userMfaRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }

    if (before.is_enabled) {
      throw new HttpError('errors.user_mfa.already_enabled', 400);
    }

    const userMfa = await userMfaRepository.update(id, { is_enabled: true });

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'ENABLE_MFA',
      entity: 'user_mfa',
      entity_id: id,
      diff: { before, after: userMfa },
      ip_address: ipAddress
    }).catch(() => {});

    return userMfa;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Disable MFA
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User MFA ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user MFA
 */
const disableMfa = async (id, userId, ipAddress) => {
  try {
    const before = await userMfaRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }

    if (!before.is_enabled) {
      throw new HttpError('errors.user_mfa.already_disabled', 400);
    }

    const userMfa = await userMfaRepository.update(id, { is_enabled: false });

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DISABLE_MFA',
      entity: 'user_mfa',
      entity_id: id,
      diff: { before, after: userMfa },
      ip_address: ipAddress
    }).catch(() => {});

    return userMfa;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listUserMfas,
  getUserMfaById,
  getUserMfasByUserId,
  createUserMfa,
  updateUserMfa,
  deleteUserMfa,
  verifyMfaCode,
  enableMfa,
  disableMfa
};
