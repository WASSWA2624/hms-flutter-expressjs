/**
 * Care Plan controller
 *
 * @module modules/care-plan/controllers
 * @description Request handlers for care plan endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const carePlanService = require('@services/care-plan/care-plan.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List care plans with pagination
 * GET /api/v1/care-plans
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listCarePlans = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    start_date,
    end_date,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    start_date,
    end_date
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await carePlanService.listCarePlans(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.care_plan.list.success', result.carePlans, result.pagination);
});

/**
 * Get care plan by ID
 * GET /api/v1/care-plans/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getCarePlanById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const carePlan = await carePlanService.getCarePlanById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.care_plan.get.success', carePlan);
});

/**
 * Create new care plan
 * POST /api/v1/care-plans
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createCarePlan = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const carePlan = await carePlanService.createCarePlan(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.care_plan.create.success', carePlan);
});

/**
 * Update care plan
 * PUT /api/v1/care-plans/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateCarePlan = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const carePlan = await carePlanService.updateCarePlan(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.care_plan.update.success', carePlan);
});

/**
 * Delete care plan (soft delete)
 * DELETE /api/v1/care-plans/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteCarePlan = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await carePlanService.deleteCarePlan(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listCarePlans,
  getCarePlanById,
  createCarePlan,
  updateCarePlan,
  deleteCarePlan
};
