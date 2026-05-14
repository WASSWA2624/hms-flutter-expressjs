/**
 * Patient Guardian service
 *
 * @module modules/patient-guardian/services
 * @description Business logic layer for patient guardian operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const patientGuardianRepository = require('@repositories/patient-guardian/patient-guardian.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List patient guardians with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Patient Guardians and pagination data
 */
const listPatientGuardians = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.name) whereClause.name = { contains: filters.name };
    if (filters.relationship) whereClause.relationship = { contains: filters.relationship };
    
    // Search filter (searches in name, relationship)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { relationship: { contains: filters.search } }
      ];
    }

    const [patientGuardians, total] = await Promise.all([
      patientGuardianRepository.findMany(whereClause, skip, limit, orderBy),
      patientGuardianRepository.count(whereClause)
    ]);

    return {
      patientGuardians,
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
 * Get patient guardian by ID
 *
 * @param {string} id - Patient Guardian ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Patient Guardian data
 */
const getPatientGuardianById = async (id, userId, ipAddress) => {
  try {
    const patientGuardian = await patientGuardianRepository.findById(id);

    if (!patientGuardian) {
      throw new HttpError('errors.patient_guardian.not_found', 404);
    }

    return patientGuardian;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient guardian
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Patient Guardian data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created patient guardian
 */
const createPatientGuardian = async (data, userId, ipAddress) => {
  try {
    const patientGuardian = await patientGuardianRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'patient_guardian',
      entity_id: patientGuardian.id,
      diff: { after: patientGuardian },
      ip_address: ipAddress
    }).catch(() => {});

    return patientGuardian;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update patient guardian
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Patient Guardian ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated patient guardian
 */
const updatePatientGuardian = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await patientGuardianRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.patient_guardian.not_found', 404);
    }

    const patientGuardian = await patientGuardianRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'patient_guardian',
      entity_id: patientGuardian.id,
      diff: { before, after: patientGuardian },
      ip_address: ipAddress
    }).catch(() => {});

    return patientGuardian;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete patient guardian (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Patient Guardian ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deletePatientGuardian = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await patientGuardianRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.patient_guardian.not_found', 404);
    }

    await patientGuardianRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'patient_guardian',
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
  listPatientGuardians,
  getPatientGuardianById,
  createPatientGuardian,
  updatePatientGuardian,
  deletePatientGuardian
};
