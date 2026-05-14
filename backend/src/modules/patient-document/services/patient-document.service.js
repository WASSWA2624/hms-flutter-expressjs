/**
 * Patient Document service
 *
 * @module modules/patient-document/services
 * @description Business logic for patient document operations.
 * Per module-creation.mdc: Services contain business logic and call audit logging for mutations.
 * Per coding-standards.mdc: Use try/catch for error translation.
 */

const patientDocumentRepository = require('@repositories/patient-document/patient-document.repository');
const { createAuditLog } = require('@lib/audit');

/**
 * List patient documents with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Patient documents and pagination metadata
 */
const listPatientDocuments = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build filters
  const where = {};
  if (filters.tenant_id) where.tenant_id = filters.tenant_id;
  if (filters.patient_id) where.patient_id = filters.patient_id;
  if (filters.document_type) where.document_type = filters.document_type;
  if (filters.search) {
    where.OR = [
      { document_type: { contains: filters.search, mode: 'insensitive' } },
      { file_name: { contains: filters.search, mode: 'insensitive' } }
    ];
  }

  const [items, total] = await Promise.all([
    patientDocumentRepository.findMany(where, skip, limit, orderBy),
    patientDocumentRepository.count(where)
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
 * Get patient document by ID
 *
 * @param {string} id - Patient document ID
 * @returns {Promise<Object|null>} Patient document or null
 */
const getPatientDocumentById = async (id) => {
  return await patientDocumentRepository.findById(id);
};

/**
 * Create patient document
 *
 * @param {Object} data - Patient document data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Created patient document
 */
const createPatientDocument = async (data, auditContext) => {
  const patientDocument = await patientDocumentRepository.create(data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'patient_document',
    entity_id: patientDocument.id,
    diff: { after: patientDocument },
    ip: auditContext.ip
  });

  return patientDocument;
};

/**
 * Update patient document
 *
 * @param {string} id - Patient document ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Updated patient document
 */
const updatePatientDocument = async (id, data, auditContext) => {
  const before = await patientDocumentRepository.findById(id);
  const patientDocument = await patientDocumentRepository.update(id, data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'patient_document',
    entity_id: patientDocument.id,
    diff: { before, after: patientDocument },
    ip: auditContext.ip
  });

  return patientDocument;
};

/**
 * Delete patient document (soft delete)
 *
 * @param {string} id - Patient document ID
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Deleted patient document
 */
const deletePatientDocument = async (id, auditContext) => {
  const before = await patientDocumentRepository.findById(id);
  const patientDocument = await patientDocumentRepository.softDelete(id);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'patient_document',
    entity_id: patientDocument.id,
    diff: { before, after: patientDocument },
    ip: auditContext.ip
  });

  return patientDocument;
};

module.exports = {
  listPatientDocuments,
  getPatientDocumentById,
  createPatientDocument,
  updatePatientDocument,
  deletePatientDocument
};
