/**
 * Lab test controller
 *
 * @module modules/lab-test/controllers
 * @description Request handlers for lab test endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const labTestService = require('@services/lab-test/lab-test.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List lab tests with pagination
 * GET /api/v1/lab-tests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listLabTests = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    code,
    category,
    specimen_type,
    result_kind,
    search,
    include_pending_review,
    include_standard_catalog,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    code,
    category,
    specimen_type,
    result_kind,
    search,
    include_pending_review,
    include_standard_catalog
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labTestService.listLabTests(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_test.list.success', result.labTests, result.pagination);
});

/**
 * Get lab test by ID
 * GET /api/v1/lab-tests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getLabTestById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labTest = await labTestService.getLabTestById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_test.get.success', labTest);
});

/**
 * Create new lab test
 * POST /api/v1/lab-tests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createLabTest = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labTest = await labTestService.createLabTest(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_test.create.success', labTest);
});

/**
 * Update lab test
 * PUT /api/v1/lab-tests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateLabTest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labTest = await labTestService.updateLabTest(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_test.update.success', labTest);
});

/**
 * Delete lab test (soft delete)
 * DELETE /api/v1/lab-tests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteLabTest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labTestService.deleteLabTest(id, userId, ipAddress);

  sendSuccess(res, 204, null, null);
});

module.exports = {
  listLabTests,
  getLabTestById,
  createLabTest,
  updateLabTest,
  deleteLabTest
};
