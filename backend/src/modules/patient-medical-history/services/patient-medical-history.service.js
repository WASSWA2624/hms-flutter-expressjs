/**
 * Patient Medical History service
 *
 * @module modules/patient-medical-history/services
 * @description Business logic for patient medical history operations.
 * Per module-creation.mdc: Services contain business logic and call audit logging for mutations.
 * Per coding-standards.mdc: Use try/catch for error translation.
 */

const patientMedicalHistoryRepository = require('@repositories/patient-medical-history/patient-medical-history.repository');
const { createAuditLog } = require('@lib/audit');

/**
 * List patient medical histories with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Patient medical histories and pagination metadata
 */
const listPatientMedicalHistories = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build filters
  const where = {};
  if (filters.tenant_id) where.tenant_id = filters.tenant_id;
  if (filters.patient_id) where.patient_id = filters.patient_id;
  if (filters.condition) {
    where.condition = {
      contains: filters.condition,
      mode: 'insensitive'
    };
  }
  if (filters.search) {
    where.OR = [
      { condition: { contains: filters.search, mode: 'insensitive' } },
      { notes: { contains: filters.search, mode: 'insensitive' } }
    ];
  }

  const [items, total] = await Promise.all([
    patientMedicalHistoryRepository.findMany(where, skip, limit, orderBy),
    patientMedicalHistoryRepository.count(where)
  ]);

  const totalPages = Math.ceil(total / limit);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1
    }
  };
};

/**
 * Get patient medical history by ID
 *
 * @param {string} id - Patient medical history ID
 * @returns {Promise<Object|null>} Patient medical history or null
 */
const getPatientMedicalHistoryById = async (id) => {
  return await patientMedicalHistoryRepository.findById(id);
};

/**
 * Create patient medical history
 *
 * @param {Object} data - Patient medical history data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Created patient medical history
 */
const createPatientMedicalHistory = async (data, auditContext) => {
  const patientMedicalHistory = await patientMedicalHistoryRepository.create(data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'patient_medical_history',
    entity_id: patientMedicalHistory.id,
    diff: { after: patientMedicalHistory },
    ip: auditContext.ip
  });

  return patientMedicalHistory;
};

/**
 * Update patient medical history
 *
 * @param {string} id - Patient medical history ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Updated patient medical history
 */
const updatePatientMedicalHistory = async (id, data, auditContext) => {
  const before = await patientMedicalHistoryRepository.findById(id);
  const patientMedicalHistory = await patientMedicalHistoryRepository.update(id, data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'patient_medical_history',
    entity_id: patientMedicalHistory.id,
    diff: { before, after: patientMedicalHistory },
    ip: auditContext.ip
  });

  return patientMedicalHistory;
};

/**
 * Delete patient medical history (soft delete)
 *
 * @param {string} id - Patient medical history ID
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Deleted patient medical history
 */
const deletePatientMedicalHistory = async (id, auditContext) => {
  const before = await patientMedicalHistoryRepository.findById(id);
  const patientMedicalHistory = await patientMedicalHistoryRepository.softDelete(id);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'patient_medical_history',
    entity_id: patientMedicalHistory.id,
    diff: { before, after: patientMedicalHistory },
    ip: auditContext.ip
  });

  return patientMedicalHistory;
};

module.exports = {
  listPatientMedicalHistories,
  getPatientMedicalHistoryById,
  createPatientMedicalHistory,
  updatePatientMedicalHistory,
  deletePatientMedicalHistory
};
