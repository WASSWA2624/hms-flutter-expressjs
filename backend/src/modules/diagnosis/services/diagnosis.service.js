/**
 * Diagnosis service
 *
 * @module modules/diagnosis/services
 * @description Business logic layer for diagnosis operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const diagnosisRepository = require('@repositories/diagnosis/diagnosis.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List diagnoses with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Diagnoses and pagination data
 */
const listDiagnoses = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.encounter_id) whereClause.encounter_id = filters.encounter_id;
    if (filters.diagnosis_type) whereClause.diagnosis_type = filters.diagnosis_type;
    if (filters.code) whereClause.code = { contains: filters.code };

    const [diagnoses, total] = await Promise.all([
      diagnosisRepository.findMany(whereClause, skip, limit, orderBy),
      diagnosisRepository.count(whereClause)
    ]);

    return {
      diagnoses,
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
 * Get diagnosis by ID
 *
 * @param {string} id - Diagnosis ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Diagnosis data
 */
const getDiagnosisById = async (id, userId, ipAddress) => {
  try {
    const diagnosis = await diagnosisRepository.findById(id);

    if (!diagnosis) {
      throw new HttpError('errors.diagnosis.not_found', 404);
    }

    return diagnosis;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new diagnosis
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Diagnosis data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created diagnosis
 */
const createDiagnosis = async (data, userId, ipAddress) => {
  try {
    const diagnosis = await diagnosisRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'diagnosis',
      entity_id: diagnosis.id,
      diff: { after: diagnosis },
      ip_address: ipAddress
    }).catch(() => {});

    return diagnosis;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update diagnosis
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Diagnosis ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated diagnosis
 */
const updateDiagnosis = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await diagnosisRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.diagnosis.not_found', 404);
    }

    const diagnosis = await diagnosisRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'diagnosis',
      entity_id: diagnosis.id,
      diff: { before, after: diagnosis },
      ip_address: ipAddress
    }).catch(() => {});

    return diagnosis;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete diagnosis (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Diagnosis ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteDiagnosis = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await diagnosisRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.diagnosis.not_found', 404);
    }

    await diagnosisRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'diagnosis',
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
  listDiagnoses,
  getDiagnosisById,
  createDiagnosis,
  updateDiagnosis,
  deleteDiagnosis
};
