/**
 * Medication administration service
 *
 * @module modules/medication-administration/services
 * @description Business logic layer for medication administration operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const medicationAdministrationRepository = require('@repositories/medication-administration/medication-administration.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List medication administrations with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Medication administrations and pagination data
 */
const listMedicationAdministrations = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.admission_id) whereClause.admission_id = filters.admission_id;
    if (filters.prescription_id) whereClause.prescription_id = filters.prescription_id;
    if (filters.route) whereClause.route = filters.route;

    const [medicationAdministrations, total] = await Promise.all([
      medicationAdministrationRepository.findMany(whereClause, skip, limit, orderBy),
      medicationAdministrationRepository.count(whereClause)
    ]);

    return {
      medicationAdministrations,
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
 * Get medication administration by ID
 *
 * @param {string} id - Medication administration ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Medication administration data
 */
const getMedicationAdministrationById = async (id, userId, ipAddress) => {
  try {
    const medicationAdministration = await medicationAdministrationRepository.findById(id);

    if (!medicationAdministration) {
      throw new HttpError('errors.medication_administration.not_found', 404);
    }

    return medicationAdministration;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new medication administration
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Medication administration data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created medication administration
 */
const createMedicationAdministration = async (data, userId, ipAddress) => {
  try {
    const medicationAdministration = await medicationAdministrationRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'medication_administration',
      entity_id: medicationAdministration.id,
      diff: { after: medicationAdministration },
      ip_address: ipAddress
    }).catch(() => {});

    return medicationAdministration;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update medication administration
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Medication administration ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated medication administration
 */
const updateMedicationAdministration = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await medicationAdministrationRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.medication_administration.not_found', 404);
    }

    const medicationAdministration = await medicationAdministrationRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'medication_administration',
      entity_id: medicationAdministration.id,
      diff: { before, after: medicationAdministration },
      ip_address: ipAddress
    }).catch(() => {});

    return medicationAdministration;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete medication administration (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Medication administration ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteMedicationAdministration = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await medicationAdministrationRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.medication_administration.not_found', 404);
    }

    await medicationAdministrationRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'medication_administration',
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
  listMedicationAdministrations,
  getMedicationAdministrationById,
  createMedicationAdministration,
  updateMedicationAdministration,
  deleteMedicationAdministration
};
