/**
 * Theatre case controller
 *
 * @module modules/theatre-case/controllers
 * @description Request handlers for theatre case endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const theatreCaseService = require('@services/theatre-case/theatre-case.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List theatre cases with pagination
 * GET /api/v1/theatre-cases
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listTheatreCases = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const {
    encounter_id,
    patient_id,
    room_id,
    surgeon_user_id,
    anesthetist_user_id,
    status,
    scheduled_from,
    scheduled_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    patient_id,
    room_id,
    surgeon_user_id,
    anesthetist_user_id,
    status,
    scheduled_from,
    scheduled_to,
    search
  };

  const result = await theatreCaseService.listTheatreCases(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.theatre_case.list.success', result.theatre_cases, result.pagination);
});

/**
 * Get theatre case by ID
 * GET /api/v1/theatre-cases/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getTheatreCaseById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const theatreCase = await theatreCaseService.getTheatreCaseById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.theatre_case.get.success', theatreCase);
});

/**
 * Create new theatre case
 * POST /api/v1/theatre-cases
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createTheatreCase = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const theatreCase = await theatreCaseService.createTheatreCase(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.theatre_case.create.success', theatreCase);
});

/**
 * Update theatre case
 * PUT /api/v1/theatre-cases/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateTheatreCase = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const theatreCase = await theatreCaseService.updateTheatreCase(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.theatre_case.update.success', theatreCase);
});

/**
 * Delete theatre case (soft delete)
 * DELETE /api/v1/theatre-cases/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteTheatreCase = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await theatreCaseService.deleteTheatreCase(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listTheatreCases,
  getTheatreCaseById,
  createTheatreCase,
  updateTheatreCase,
  deleteTheatreCase
};
