/**
 * Medication administration controller
 *
 * @module modules/medication-administration/controllers
 * @description Request handlers for medication administration endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const medicationAdministrationService = require('@services/medication-administration/medication-administration.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List medication administrations with pagination
 * GET /api/v1/medication-administrations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listMedicationAdministrations = asyncHandler(async (req, res) => {
  const {
    admission_id,
    prescription_id,
    route,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id,
    prescription_id,
    route
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await medicationAdministrationService.listMedicationAdministrations(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.medication_administration.list.success', result.medicationAdministrations, result.pagination);
});

/**
 * Get medication administration by ID
 * GET /api/v1/medication-administrations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getMedicationAdministrationById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const medicationAdministration = await medicationAdministrationService.getMedicationAdministrationById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.medication_administration.get.success', medicationAdministration);
});

/**
 * Create new medication administration
 * POST /api/v1/medication-administrations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createMedicationAdministration = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const medicationAdministration = await medicationAdministrationService.createMedicationAdministration(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.medication_administration.create.success', medicationAdministration);
});

/**
 * Update medication administration
 * PUT /api/v1/medication-administrations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateMedicationAdministration = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const medicationAdministration = await medicationAdministrationService.updateMedicationAdministration(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.medication_administration.update.success', medicationAdministration);
});

/**
 * Delete medication administration (soft delete)
 * DELETE /api/v1/medication-administrations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteMedicationAdministration = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await medicationAdministrationService.deleteMedicationAdministration(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listMedicationAdministrations,
  getMedicationAdministrationById,
  createMedicationAdministration,
  updateMedicationAdministration,
  deleteMedicationAdministration
};
