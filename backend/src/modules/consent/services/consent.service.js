/**
 * Consent service
 *
 * @module modules/consent/services
 * @description Business logic layer for consent operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const consentRepository = require('@repositories/consent/consent.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List consents with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Consents and pagination data
 */
const listConsents = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.consent_type) whereClause.consent_type = filters.consent_type;
    if (filters.status) whereClause.status = filters.status;

    const [consents, total] = await Promise.all([
      consentRepository.findMany(whereClause, skip, limit, orderBy),
      consentRepository.count(whereClause)
    ]);

    return {
      consents,
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
 * Get consent by ID
 *
 * @param {string} id - Consent ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Consent data
 */
const getConsentById = async (id, userId, ipAddress) => {
  try {
    const consent = await consentRepository.findById(id);

    if (!consent) {
      throw new HttpError('errors.consent.not_found', 404);
    }

    return consent;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new consent
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Consent data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created consent
 */
const createConsent = async (data, userId, ipAddress) => {
  try {
    const consent = await consentRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'consent',
      entity_id: consent.id,
      diff: { after: consent },
      ip_address: ipAddress
    }).catch(() => {});

    return consent;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update consent
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Consent ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated consent
 */
const updateConsent = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await consentRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.consent.not_found', 404);
    }

    const consent = await consentRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'consent',
      entity_id: consent.id,
      diff: { before, after: consent },
      ip_address: ipAddress
    }).catch(() => {});

    return consent;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete consent (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Consent ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteConsent = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await consentRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.consent.not_found', 404);
    }

    await consentRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'consent',
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
  listConsents,
  getConsentById,
  createConsent,
  updateConsent,
  deleteConsent
};
