/**
 * Patient Document controller
 *
 * @module modules/patient-document/controllers
 * @description Controllers for patient document endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use response helpers for consistent output.
 */

const patientDocumentService = require('@services/patient-document/patient-document.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient documents
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listPatientDocuments = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    ...filters
  } = req.query;

  const result = await patientDocumentService.listPatientDocuments(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.patient_document.list.success',
    result.items,
    result.pagination
  );
};

/**
 * Get patient document by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getPatientDocumentById = async (req, res) => {
  const { id } = req.params;

  const patientDocument = await patientDocumentService.getPatientDocumentById(id);

  if (!patientDocument) {
    throw new HttpError('errors.patient_document.not_found', 404);
  }

  return sendSuccess(res, 200, 'messages.patient_document.get.success', patientDocument);
};

/**
 * Create patient document
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createPatientDocument = async (req, res) => {
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const patientDocument = await patientDocumentService.createPatientDocument(data, auditContext);

  return sendSuccess(res, 201, 'messages.patient_document.create.success', patientDocument);
};

/**
 * Update patient document
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updatePatientDocument = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const patientDocument = await patientDocumentService.updatePatientDocument(id, data, auditContext);

  return sendSuccess(res, 200, 'messages.patient_document.update.success', patientDocument);
};

/**
 * Delete patient document (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deletePatientDocument = async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  await patientDocumentService.deletePatientDocument(id, auditContext);

  return res.status(204).send();
};

module.exports = {
  listPatientDocuments,
  getPatientDocumentById,
  createPatientDocument,
  updatePatientDocument,
  deletePatientDocument
};
