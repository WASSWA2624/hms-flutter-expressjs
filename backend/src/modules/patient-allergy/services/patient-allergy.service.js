/**
 * Patient Allergy service
 *
 * @module modules/patient-allergy/services
 * @description Business logic for patient allergy operations.
 * Per module-creation.mdc: Services contain business logic and call audit logging for mutations.
 * Per coding-standards.mdc: Use try/catch for error translation.
 */

const patientAllergyRepository = require('@repositories/patient-allergy/patient-allergy.repository');
const { createAuditLog } = require('@lib/audit');

/**
 * List patient allergies with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Patient allergies and pagination metadata
 */
const listPatientAllergies = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build filters
  const where = {};
  if (filters.tenant_id) where.tenant_id = filters.tenant_id;
  if (filters.patient_id) where.patient_id = filters.patient_id;
  if (filters.severity) where.severity = filters.severity;
  if (filters.allergen) {
    where.allergen = {
      contains: filters.allergen,
      mode: 'insensitive'
    };
  }
  if (filters.search) {
    where.OR = [
      { allergen: { contains: filters.search, mode: 'insensitive' } },
      { reaction: { contains: filters.search, mode: 'insensitive' } }
    ];
  }

  const [items, total] = await Promise.all([
    patientAllergyRepository.findMany(where, skip, limit, orderBy),
    patientAllergyRepository.count(where)
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
 * Get patient allergy by ID
 *
 * @param {string} id - Patient allergy ID
 * @returns {Promise<Object|null>} Patient allergy or null
 */
const getPatientAllergyById = async (id) => {
  return await patientAllergyRepository.findById(id);
};

/**
 * Create patient allergy
 *
 * @param {Object} data - Patient allergy data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Created patient allergy
 */
const createPatientAllergy = async (data, auditContext) => {
  const patientAllergy = await patientAllergyRepository.create(data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'patient_allergy',
    entity_id: patientAllergy.id,
    diff: { after: patientAllergy },
    ip: auditContext.ip
  });

  return patientAllergy;
};

/**
 * Update patient allergy
 *
 * @param {string} id - Patient allergy ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Updated patient allergy
 */
const updatePatientAllergy = async (id, data, auditContext) => {
  const before = await patientAllergyRepository.findById(id);
  const patientAllergy = await patientAllergyRepository.update(id, data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'patient_allergy',
    entity_id: patientAllergy.id,
    diff: { before, after: patientAllergy },
    ip: auditContext.ip
  });

  return patientAllergy;
};

/**
 * Delete patient allergy (soft delete)
 *
 * @param {string} id - Patient allergy ID
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Deleted patient allergy
 */
const deletePatientAllergy = async (id, auditContext) => {
  const before = await patientAllergyRepository.findById(id);
  const patientAllergy = await patientAllergyRepository.softDelete(id);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'patient_allergy',
    entity_id: patientAllergy.id,
    diff: { before, after: patientAllergy },
    ip: auditContext.ip
  });

  return patientAllergy;
};

module.exports = {
  listPatientAllergies,
  getPatientAllergyById,
  createPatientAllergy,
  updatePatientAllergy,
  deletePatientAllergy
};
