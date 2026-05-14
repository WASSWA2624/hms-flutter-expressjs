/**
 * Ward Round controller
 *
 * @module modules/ward-round/controllers
 * @description Request handlers for ward round endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const wardRoundService = require('@services/ward-round/ward-round.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List ward rounds with pagination
 * GET /api/v1/ward-rounds
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listWardRounds = asyncHandler(async (req, res) => {
  const {
    admission_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await wardRoundService.listWardRounds(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.ward_round.list.success', result.wardRounds, result.pagination);
});

/**
 * Get ward round by ID
 * GET /api/v1/ward-rounds/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getWardRoundById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const wardRound = await wardRoundService.getWardRoundById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.ward_round.get.success', wardRound);
});

/**
 * Create new ward round
 * POST /api/v1/ward-rounds
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createWardRound = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const wardRound = await wardRoundService.createWardRound(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.ward_round.create.success', wardRound);
});

/**
 * Update ward round
 * PUT /api/v1/ward-rounds/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateWardRound = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const wardRound = await wardRoundService.updateWardRound(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.ward_round.update.success', wardRound);
});

/**
 * Delete ward round (soft delete)
 * DELETE /api/v1/ward-rounds/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteWardRound = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await wardRoundService.deleteWardRound(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listWardRounds,
  getWardRoundById,
  createWardRound,
  updateWardRound,
  deleteWardRound
};
