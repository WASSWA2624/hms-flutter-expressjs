/**
 * Shift swap request controller
 *
 * @module modules/shift-swap-request/controllers
 * @description Request handlers for shift swap request endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const shiftSwapRequestService = require('@services/shift-swap-request/shift-swap-request.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listShiftSwapRequests = asyncHandler(async (req, res) => {
  const { shift_id, requester_staff_id, target_staff_id, status, page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'asc' } = req.query;
  const filters = { shift_id, requester_staff_id, target_staff_id, status };
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await shiftSwapRequestService.listShiftSwapRequests(
    filters, parseInt(page), parseInt(limit), sort_by, order, userId, ipAddress
  );

  sendPaginated(res, 'messages.shift_swap_request.list.success', result.shiftSwapRequests, result.pagination);
});

const getShiftSwapRequestById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const shiftSwapRequest = await shiftSwapRequestService.getShiftSwapRequestById(id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.shift_swap_request.get.success', shiftSwapRequest);
});

const createShiftSwapRequest = asyncHandler(async (req, res) => {
  const shiftSwapRequest = await shiftSwapRequestService.createShiftSwapRequest(req.body, req.user?.id, req.ip);
  sendSuccess(res, 201, 'messages.shift_swap_request.create.success', shiftSwapRequest);
});

const updateShiftSwapRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const shiftSwapRequest = await shiftSwapRequestService.updateShiftSwapRequest(id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.shift_swap_request.update.success', shiftSwapRequest);
});

const deleteShiftSwapRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await shiftSwapRequestService.deleteShiftSwapRequest(id, req.user?.id, req.ip);
  sendNoContent(res);
});

module.exports = {
  listShiftSwapRequests,
  getShiftSwapRequestById,
  createShiftSwapRequest,
  updateShiftSwapRequest,
  deleteShiftSwapRequest
};
