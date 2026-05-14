/**
 * API Key service
 *
 * @module modules/api-key/services
 * @description Business logic layer for API key operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 * Per auth-security.mdc: API keys must be hashed with Argon2id.
 */

const crypto = require('crypto');
const apiKeyRepository = require('@repositories/api-key/api-key.repository');
const { createAuditLog } = require('@lib/audit');
const { hashApiKey } = require('@lib/crypto');
const { HttpError } = require('@lib/errors');

/**
 * Generate a secure random API key
 * Per auth-security.mdc: API keys must be strong, random, and unique
 *
 * @returns {string} Random API key (64 characters)
 */
const generateSecureApiKey = () => {
  // Generate 32 random bytes and convert to hex (64 characters)
  return crypto.randomBytes(32).toString('hex');
};

/**
 * List API keys with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} API keys and pagination data
 */
const listApiKeys = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.user_id) whereClause.user_id = filters.user_id;
    if (filters.is_active !== undefined) whereClause.is_active = filters.is_active;
    
    // Search filter (searches in name)
    if (filters.search) {
      whereClause.name = { contains: filters.search };
    }

    const [apiKeys, total] = await Promise.all([
      apiKeyRepository.findMany(whereClause, skip, limit, orderBy),
      apiKeyRepository.count(whereClause)
    ]);

    // Remove sensitive key_hash from response
    const sanitizedApiKeys = apiKeys.map(({ key_hash, ...apiKey }) => apiKey);

    return {
      api_keys: sanitizedApiKeys,
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
 * Get API key by ID
 *
 * @param {string} id - API key ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} API key data
 */
const getApiKeyById = async (id, userId, ipAddress) => {
  try {
    const apiKey = await apiKeyRepository.findById(id);

    if (!apiKey) {
      throw new HttpError('errors.api_key.not_found', 404);
    }

    // Remove sensitive key_hash from response
    const { key_hash, ...sanitizedApiKey } = apiKey;

    return sanitizedApiKey;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new API key
 * Per prisma.mdc: Mutations must create audit logs
 * Per auth-security.mdc: API keys must be hashed with Argon2id
 *
 * @param {Object} data - API key data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created API key with plain key (only returned once)
 */
const createApiKey = async (data, userId, ipAddress) => {
  try {
    const humanFriendlyId = apiKeyRepository.createPublicId('KEY');
    const apiKeySecret = generateSecureApiKey();
    const plainApiKey = `${humanFriendlyId}.${apiKeySecret}`;

    // Hash the full presented key so prefix disclosure does not weaken storage.
    const keyHash = await hashApiKey(plainApiKey);

    // Create API key with hashed key
    const apiKeyData = {
      ...data,
      human_friendly_id: humanFriendlyId,
      key_hash: keyHash,
      is_active: true
    };

    const apiKey = await apiKeyRepository.create(apiKeyData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'api_key',
      entity_id: apiKey.id,
      diff: { after: { ...apiKey, key_hash: '[REDACTED]' } },
      ip_address: ipAddress
    }).catch(() => {});

    // Remove key_hash from response and include plain key (only time it's shown)
    const { key_hash, ...sanitizedApiKey } = apiKey;

    return {
      ...sanitizedApiKey,
      api_key: plainApiKey // Plain key only returned on creation
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update API key
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - API key ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated API key
 */
const updateApiKey = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await apiKeyRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.api_key.not_found', 404);
    }

    const apiKey = await apiKeyRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'api_key',
      entity_id: apiKey.id,
      diff: { 
        before: { ...before, key_hash: '[REDACTED]' },
        after: { ...apiKey, key_hash: '[REDACTED]' }
      },
      ip_address: ipAddress
    }).catch(() => {});

    // Remove sensitive key_hash from response
    const { key_hash, ...sanitizedApiKey } = apiKey;

    return sanitizedApiKey;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete API key (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - API key ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteApiKey = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await apiKeyRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.api_key.not_found', 404);
    }

    await apiKeyRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'api_key',
      entity_id: id,
      diff: { before: { ...before, key_hash: '[REDACTED]' } },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listApiKeys,
  getApiKeyById,
  createApiKey,
  updateApiKey,
  deleteApiKey
};
