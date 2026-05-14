/**
 * Patient Medical History controller
 *
 * @module modules/patient-medical-history/controllers
 * @description Controllers for patient medical history endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use response helpers for consistent output.
 */

const patientMedicalHistoryService = require('@services/patient-medical-history/patient-medical-history.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient medical histories
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listPatientMedicalHistories = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    ...filters
  } = req.query;

  const result = await patientMedicalHistoryService.listPatientMedicalHistories(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.patient_medical_history.list.success',
    result.items,
    result.pagination
  );
};

/**
 * Get patient medical history by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getPatientMedicalHistoryById = async (req, res) => {
  const { id } = req.params;

  const patientMedicalHistory = await patientMedicalHistoryService.getPatientMedicalHistoryById(id);

  if (!patientMedicalHistory) {
    throw new HttpError('errors.patient_medical_history.not_found', 404);
  }

  return sendSuccess(res, 200, 'messages.patient_medical_history.get.success', patientMedicalHistory);
};

/**
 * Create patient medical history
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createPatientMedicalHistory = async (req, res) => {
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const patientMedicalHistory = await patientMedicalHistoryService.createPatientMedicalHistory(data, auditContext);

  return sendSuccess(res, 201, 'messages.patient_medical_history.create.success', patientMedicalHistory);
};

/**
 * Update patient medical history
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updatePatientMedicalHistory = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const patientMedicalHistory = await patientMedicalHistoryService.updatePatientMedicalHistory(id, data, auditContext);

  return sendSuccess(res, 200, 'messages.patient_medical_history.update.success', patientMedicalHistory);
};

/**
 * Delete patient medical history (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deletePatientMedicalHistory = async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  await patientMedicalHistoryService.deletePatientMedicalHistory(id, auditContext);

  return res.status(204).send();
};

module.exports = {
  listPatientMedicalHistories,
  getPatientMedicalHistoryById,
  createPatientMedicalHistory,
  updatePatientMedicalHistory,
  deletePatientMedicalHistory
};
