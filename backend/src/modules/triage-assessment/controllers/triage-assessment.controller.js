/**
 * Triage assessment controller
 *
 * @module modules/triage-assessment/controllers
 * @description Request handlers for triage assessment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use @lib/response/* for output.
 */

const triageAssessmentService = require('@modules/triage-assessment/services/triage-assessment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List triage assessments
 * GET /api/v1/triage-assessments
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listTriageAssessments = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    emergency_case_id,
    triage_level,
    search
  } = req.query;

  const filters = {};
  if (emergency_case_id) filters.emergency_case_id = emergency_case_id;
  if (triage_level) filters.triage_level = triage_level;
  if (search) filters.search = search;

  const result = await triageAssessmentService.listTriageAssessments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  const pagination = {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1
  };

  sendPaginated(res, 'messages.triage_assessment.list.success', result.items, pagination);
});

/**
 * Get triage assessment by ID
 * GET /api/v1/triage-assessments/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getTriageAssessmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const triageAssessment = await triageAssessmentService.getTriageAssessmentById(id);

  sendSuccess(res, 200, 'messages.triage_assessment.get.success', triageAssessment);
});

/**
 * Create triage assessment
 * POST /api/v1/triage-assessments
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createTriageAssessment = asyncHandler(async (req, res) => {
  const data = req.body;
  const user = req.user;

  const triageAssessment = await triageAssessmentService.createTriageAssessment(data, user);

  sendSuccess(res, 201, 'messages.triage_assessment.create.success', triageAssessment);
});

/**
 * Update triage assessment
 * PUT /api/v1/triage-assessments/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateTriageAssessment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const user = req.user;

  const triageAssessment = await triageAssessmentService.updateTriageAssessment(id, data, user);

  sendSuccess(res, 200, 'messages.triage_assessment.update.success', triageAssessment);
});

/**
 * Delete triage assessment (soft delete)
 * DELETE /api/v1/triage-assessments/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteTriageAssessment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const user = req.user;

  await triageAssessmentService.deleteTriageAssessment(id, user);

  sendNoContent(res);
});

module.exports = {
  listTriageAssessments,
  getTriageAssessmentById,
  createTriageAssessment,
  updateTriageAssessment,
  deleteTriageAssessment
};
