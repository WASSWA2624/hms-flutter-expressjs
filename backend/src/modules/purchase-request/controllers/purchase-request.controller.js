/**
 * Purchase request controller
 *
 * @module modules/purchase-request/controllers
 * @description HTTP request handlers for purchase request endpoints.
 * Per module-creation.mdc: Controllers handle HTTP, call services, return responses.
 * All handlers must be wrapped with asyncHandler.
 */

const purchaseRequestService = require('@services/purchase-request/purchase-request.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendCreated, sendNoContent } = require('@lib/response');

/**
 * Get purchase request by ID
 * GET /api/v1/purchase-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPurchaseRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  const purchaseRequest = await purchaseRequestService.getPurchaseRequestById(id);
  
  sendSuccess(res, purchaseRequest, 'messages.purchase_request.retrieved', req.locale);
});

/**
 * List purchase requests with pagination
 * GET /api/v1/purchase-requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPurchaseRequests = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  
  const result = await purchaseRequestService.listPurchaseRequests(
    filters,
    { page: parseInt(page) || 1, limit: parseInt(limit) || 20 },
    { sort_by, order }
  );
  
  sendSuccess(res, result.data, 'messages.purchase_request.list_retrieved', req.locale, {
    pagination: {
      page: result.page,
      limit: result.limit,
      total: result.total,
      total_pages: Math.ceil(result.total / result.limit)
    }
  });
});

/**
 * Create new purchase request
 * POST /api/v1/purchase-requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPurchaseRequest = asyncHandler(async (req, res) => {
  const purchaseRequestData = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip_address: req.ip
  };
  
  const purchaseRequest = await purchaseRequestService.createPurchaseRequest(purchaseRequestData, auditContext);
  
  sendCreated(res, purchaseRequest, 'messages.purchase_request.created', req.locale);
});

/**
 * Update purchase request
 * PUT /api/v1/purchase-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePurchaseRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateData = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip_address: req.ip
  };
  
  const purchaseRequest = await purchaseRequestService.updatePurchaseRequest(id, updateData, auditContext);
  
  sendSuccess(res, purchaseRequest, 'messages.purchase_request.updated', req.locale);
});

/**
 * Delete purchase request (soft delete)
 * DELETE /api/v1/purchase-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePurchaseRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip_address: req.ip
  };
  
  await purchaseRequestService.deletePurchaseRequest(id, auditContext);
  
  sendNoContent(res);
});

module.exports = {
  getPurchaseRequest,
  listPurchaseRequests,
  createPurchaseRequest,
  updatePurchaseRequest,
  deletePurchaseRequest
};
