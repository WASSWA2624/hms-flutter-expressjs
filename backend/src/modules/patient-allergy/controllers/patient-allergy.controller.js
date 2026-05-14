/**
 * Patient Allergy controller
 *
 * @module modules/patient-allergy/controllers
 * @description Controllers for patient allergy endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use response helpers for consistent output.
 */

const patientAllergyService = require('@services/patient-allergy/patient-allergy.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient allergies
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listPatientAllergies = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    ...filters
  } = req.query;

  const result = await patientAllergyService.listPatientAllergies(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.patient_allergy.list.success',
    result.items,
    result.pagination
  );
};

/**
 * Get patient allergy by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getPatientAllergyById = async (req, res) => {
  const { id } = req.params;

  const patientAllergy = await patientAllergyService.getPatientAllergyById(id);

  if (!patientAllergy) {
    throw new HttpError('errors.patient_allergy.not_found', 404);
  }

  return sendSuccess(res, 200, 'messages.patient_allergy.get.success', patientAllergy);
};

/**
 * Create patient allergy
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createPatientAllergy = async (req, res) => {
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const patientAllergy = await patientAllergyService.createPatientAllergy(data, auditContext);

  return sendSuccess(res, 201, 'messages.patient_allergy.create.success', patientAllergy);
};

/**
 * Update patient allergy
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updatePatientAllergy = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const patientAllergy = await patientAllergyService.updatePatientAllergy(id, data, auditContext);

  return sendSuccess(res, 200, 'messages.patient_allergy.update.success', patientAllergy);
};

/**
 * Delete patient allergy (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deletePatientAllergy = async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  await patientAllergyService.deletePatientAllergy(id, auditContext);

  return res.status(204).send();
};

module.exports = {
  listPatientAllergies,
  getPatientAllergyById,
  createPatientAllergy,
  updatePatientAllergy,
  deletePatientAllergy
};
