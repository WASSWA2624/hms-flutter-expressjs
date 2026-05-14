/**
 * Imaging study controller
 *
 * @module modules/imaging-study/controllers
 * @description Request handlers for imaging study endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const imagingStudyService = require('@services/imaging-study/imaging-study.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List imaging studies with pagination
 * GET /api/v1/imaging-studies
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listImagingStudies = asyncHandler(async (req, res) => {
  const {
    radiology_order_id,
    modality,
    performed_at,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    radiology_order_id,
    modality,
    performed_at
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await imagingStudyService.listImagingStudies(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.imaging_study.list.success', result.imagingStudies, result.pagination);
});

/**
 * Get imaging study by ID
 * GET /api/v1/imaging-studies/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getImagingStudyById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const imagingStudy = await imagingStudyService.getImagingStudyById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.imaging_study.get.success', imagingStudy);
});

/**
 * Create new imaging study
 * POST /api/v1/imaging-studies
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createImagingStudy = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const imagingStudy = await imagingStudyService.createImagingStudy(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.imaging_study.create.success', imagingStudy);
});

/**
 * Update imaging study
 * PUT /api/v1/imaging-studies/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateImagingStudy = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const imagingStudy = await imagingStudyService.updateImagingStudy(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.imaging_study.update.success', imagingStudy);
});

/**
 * Delete imaging study (soft delete)
 * DELETE /api/v1/imaging-studies/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteImagingStudy = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await imagingStudyService.deleteImagingStudy(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listImagingStudies,
  getImagingStudyById,
  createImagingStudy,
  updateImagingStudy,
  deleteImagingStudy
};
