/**
 * Patient Identifier service
 *
 * @module modules/patient-identifier/services
 * @description Business logic layer for patient identifier operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const patientIdentifierRepository = require('@repositories/patient-identifier/patient-identifier.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List patient identifiers with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Patient Identifiers and pagination data
 */
const listPatientIdentifiers = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.identifier_type) whereClause.identifier_type = { contains: filters.identifier_type };
    if (filters.identifier_value) whereClause.identifier_value = { contains: filters.identifier_value };
    if (filters.is_primary !== undefined) whereClause.is_primary = filters.is_primary;

    const [patientIdentifiers, total] = await Promise.all([
      patientIdentifierRepository.findMany(whereClause, skip, limit, orderBy),
      patientIdentifierRepository.count(whereClause)
    ]);

    return {
      patientIdentifiers,
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
 * Get patient identifier by ID
 *
 * @param {string} id - Patient Identifier ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Patient Identifier data
 */
const getPatientIdentifierById = async (id, userId, ipAddress) => {
  try {
    const patientIdentifier = await patientIdentifierRepository.findById(id);

    if (!patientIdentifier) {
      throw new HttpError('errors.patient_identifier.not_found', 404);
    }

    return patientIdentifier;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient identifier
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Patient Identifier data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created patient identifier
 */
const createPatientIdentifier = async (data, userId, ipAddress) => {
  try {
    const patientIdentifier = await patientIdentifierRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'patient_identifier',
      entity_id: patientIdentifier.id,
      diff: { after: patientIdentifier },
      ip_address: ipAddress
    }).catch(() => {});

    return patientIdentifier;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update patient identifier
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Patient Identifier ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated patient identifier
 */
const updatePatientIdentifier = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await patientIdentifierRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.patient_identifier.not_found', 404);
    }

    const patientIdentifier = await patientIdentifierRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'patient_identifier',
      entity_id: patientIdentifier.id,
      diff: { before, after: patientIdentifier },
      ip_address: ipAddress
    }).catch(() => {});

    return patientIdentifier;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete patient identifier (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Patient Identifier ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deletePatientIdentifier = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await patientIdentifierRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.patient_identifier.not_found', 404);
    }

    await patientIdentifierRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'patient_identifier',
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
  listPatientIdentifiers,
  getPatientIdentifierById,
  createPatientIdentifier,
  updatePatientIdentifier,
  deletePatientIdentifier
};
