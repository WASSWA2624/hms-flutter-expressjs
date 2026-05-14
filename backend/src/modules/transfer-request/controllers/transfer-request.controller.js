/**
 * Transfer request controller
 *
 * @module modules/transfer-request/controllers
 * @description Request handlers for transfer request endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const transferRequestService = require('@services/transfer-request/transfer-request.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List transfer requests with pagination
 * GET /api/v1/transfer-requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listTransferRequests = asyncHandler(async (req, res) => {
  const {
    admission_id,
    from_ward_id,
    to_ward_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id,
    from_ward_id,
    to_ward_id,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await transferRequestService.listTransferRequests(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.transfer_request.list.success', result.transferRequests, result.pagination);
});

/**
 * Get transfer request by ID
 * GET /api/v1/transfer-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getTransferRequestById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const transferRequest = await transferRequestService.getTransferRequestById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.transfer_request.get.success', transferRequest);
});

/**
 * Create new transfer request
 * POST /api/v1/transfer-requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createTransferRequest = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const transferRequest = await transferRequestService.createTransferRequest(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.transfer_request.create.success', transferRequest);
});

/**
 * Update transfer request
 * PUT /api/v1/transfer-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateTransferRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const transferRequest = await transferRequestService.updateTransferRequest(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.transfer_request.update.success', transferRequest);
});

/**
 * Delete transfer request (soft delete)
 * DELETE /api/v1/transfer-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteTransferRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await transferRequestService.deleteTransferRequest(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listTransferRequests,
  getTransferRequestById,
  createTransferRequest,
  updateTransferRequest,
  deleteTransferRequest
};
