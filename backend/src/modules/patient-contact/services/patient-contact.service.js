/**
 * Patient Contact service
 *
 * @module modules/patient-contact/services
 * @description Business logic layer for patient contact operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const patientContactRepository = require('@repositories/patient-contact/patient-contact.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List patient contacts with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Patient Contacts and pagination data
 */
const listPatientContacts = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.contact_type) whereClause.contact_type = filters.contact_type;
    if (filters.value) whereClause.value = { contains: filters.value };
    if (filters.is_primary !== undefined) whereClause.is_primary = filters.is_primary;

    const [patientContacts, total] = await Promise.all([
      patientContactRepository.findMany(whereClause, skip, limit, orderBy),
      patientContactRepository.count(whereClause)
    ]);

    return {
      patientContacts,
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
 * Get patient contact by ID
 *
 * @param {string} id - Patient Contact ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Patient Contact data
 */
const getPatientContactById = async (id, userId, ipAddress) => {
  try {
    const patientContact = await patientContactRepository.findById(id);

    if (!patientContact) {
      throw new HttpError('errors.patient_contact.not_found', 404);
    }

    return patientContact;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient contact
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Patient Contact data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created patient contact
 */
const createPatientContact = async (data, userId, ipAddress) => {
  try {
    const patientContact = await patientContactRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'patient_contact',
      entity_id: patientContact.id,
      diff: { after: patientContact },
      ip_address: ipAddress
    }).catch(() => {});

    return patientContact;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update patient contact
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Patient Contact ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated patient contact
 */
const updatePatientContact = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await patientContactRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.patient_contact.not_found', 404);
    }

    const patientContact = await patientContactRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'patient_contact',
      entity_id: patientContact.id,
      diff: { before, after: patientContact },
      ip_address: ipAddress
    }).catch(() => {});

    return patientContact;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete patient contact (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Patient Contact ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deletePatientContact = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await patientContactRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.patient_contact.not_found', 404);
    }

    await patientContactRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'patient_contact',
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
  listPatientContacts,
  getPatientContactById,
  createPatientContact,
  updatePatientContact,
  deletePatientContact
};
