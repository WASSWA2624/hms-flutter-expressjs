/**
 * ICU Stay controller
 *
 * @module modules/icu-stay/controllers
 * @description Request handlers for ICU stay endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const icuStayService = require('@services/icu-stay/icu-stay.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List ICU stays with pagination
 * GET /api/v1/icu-stays
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listIcuStays = asyncHandler(async (req, res) => {
  const {
    admission_id,
    started_at_from,
    started_at_to,
    ended_at_from,
    ended_at_to,
    is_active,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id,
    started_at_from,
    started_at_to,
    ended_at_from,
    ended_at_to,
    is_active
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await icuStayService.listIcuStays(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.icu_stay.list.success', result.icu_stays, result.pagination);
});

/**
 * Get ICU stay by ID
 * GET /api/v1/icu-stays/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getIcuStayById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const icuStay = await icuStayService.getIcuStayById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.icu_stay.get.success', icuStay);
});

/**
 * Create new ICU stay
 * POST /api/v1/icu-stays
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createIcuStay = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const icuStay = await icuStayService.createIcuStay(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.icu_stay.create.success', icuStay);
});

/**
 * Update ICU stay
 * PUT /api/v1/icu-stays/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateIcuStay = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const icuStay = await icuStayService.updateIcuStay(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.icu_stay.update.success', icuStay);
});

/**
 * Delete ICU stay (soft delete)
 * DELETE /api/v1/icu-stays/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteIcuStay = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await icuStayService.deleteIcuStay(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listIcuStays,
  getIcuStayById,
  createIcuStay,
  updateIcuStay,
  deleteIcuStay
};
