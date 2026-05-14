/**
 * ICU Observation controller
 *
 * @module modules/icu-observation/controllers
 * @description Request handlers for ICU observation endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const icuObservationService = require('@services/icu-observation/icu-observation.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List ICU observations with pagination
 * GET /api/v1/icu-observations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listIcuObservations = asyncHandler(async (req, res) => {
  const {
    icu_stay_id,
    observed_at_from,
    observed_at_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    icu_stay_id,
    observed_at_from,
    observed_at_to,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await icuObservationService.listIcuObservations(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.icu_observation.list.success', result.icu_observations, result.pagination);
});

/**
 * Get ICU observation by ID
 * GET /api/v1/icu-observations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getIcuObservationById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const icuObservation = await icuObservationService.getIcuObservationById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.icu_observation.get.success', icuObservation);
});

/**
 * Create new ICU observation
 * POST /api/v1/icu-observations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createIcuObservation = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const icuObservation = await icuObservationService.createIcuObservation(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.icu_observation.create.success', icuObservation);
});

/**
 * Update ICU observation
 * PUT /api/v1/icu-observations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateIcuObservation = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const icuObservation = await icuObservationService.updateIcuObservation(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.icu_observation.update.success', icuObservation);
});

/**
 * Delete ICU observation (soft delete)
 * DELETE /api/v1/icu-observations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteIcuObservation = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await icuObservationService.deleteIcuObservation(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listIcuObservations,
  getIcuObservationById,
  createIcuObservation,
  updateIcuObservation,
  deleteIcuObservation
};
