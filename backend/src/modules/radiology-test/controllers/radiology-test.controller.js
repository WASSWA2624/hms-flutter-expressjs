/**
 * Radiology test controller
 *
 * @module modules/radiology-test/controllers
 * @description Request handlers for radiology test endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const radiologyTestService = require('@services/radiology-test/radiology-test.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List radiology tests with pagination
 * GET /api/v1/radiology-tests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listRadiologyTests = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    code,
    modality,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    code,
    modality,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await radiologyTestService.listRadiologyTests(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.radiology_test.list.success', result.radiologyTests, result.pagination);
});

/**
 * Get radiology test by ID
 * GET /api/v1/radiology-tests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getRadiologyTestById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyTest = await radiologyTestService.getRadiologyTestById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_test.get.success', radiologyTest);
});

/**
 * Create new radiology test
 * POST /api/v1/radiology-tests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createRadiologyTest = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyTest = await radiologyTestService.createRadiologyTest(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.radiology_test.create.success', radiologyTest);
});

/**
 * Update radiology test
 * PUT /api/v1/radiology-tests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateRadiologyTest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyTest = await radiologyTestService.updateRadiologyTest(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_test.update.success', radiologyTest);
});

/**
 * Delete radiology test (soft delete)
 * DELETE /api/v1/radiology-tests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteRadiologyTest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await radiologyTestService.deleteRadiologyTest(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listRadiologyTests,
  getRadiologyTestById,
  createRadiologyTest,
  updateRadiologyTest,
  deleteRadiologyTest
};
