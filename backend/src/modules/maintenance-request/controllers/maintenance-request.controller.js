/**
 * Maintenance request controller
 *
 * @module modules/maintenance-request/controllers
 * @description Request handlers for maintenance request endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const maintenanceRequestService = require('@services/maintenance-request/maintenance-request.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List maintenance requests with pagination
 * GET /api/v1/maintenance-requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listMaintenanceRequests = asyncHandler(async (req, res) => {
  const {
    facility_id,
    asset_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    facility_id,
    asset_id,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await maintenanceRequestService.listMaintenanceRequests(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.maintenance_request.list.success', result.maintenanceRequests, result.pagination);
});

/**
 * Get maintenance request by ID
 * GET /api/v1/maintenance-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getMaintenanceRequestById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const maintenanceRequest = await maintenanceRequestService.getMaintenanceRequestById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.maintenance_request.get.success', maintenanceRequest);
});

/**
 * Create new maintenance request
 * POST /api/v1/maintenance-requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createMaintenanceRequest = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const maintenanceRequest = await maintenanceRequestService.createMaintenanceRequest(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.maintenance_request.create.success', maintenanceRequest);
});

/**
 * Update maintenance request
 * PUT /api/v1/maintenance-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateMaintenanceRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const maintenanceRequest = await maintenanceRequestService.updateMaintenanceRequest(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.maintenance_request.update.success', maintenanceRequest);
});

/**
 * Delete maintenance request (soft delete)
 * DELETE /api/v1/maintenance-requests/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteMaintenanceRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await maintenanceRequestService.deleteMaintenanceRequest(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Triage maintenance request
 * POST /api/v1/maintenance-requests/:id/triage
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const triageMaintenanceRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const maintenanceRequest = await maintenanceRequestService.triageMaintenanceRequest(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.maintenance_request.triage.success', maintenanceRequest);
});

const convertMaintenanceRequestToWorkOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await maintenanceRequestService.convertMaintenanceRequestToWorkOrder(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.maintenance_request.convert.success', result);
});

module.exports = {
  listMaintenanceRequests,
  getMaintenanceRequestById,
  createMaintenanceRequest,
  updateMaintenanceRequest,
  deleteMaintenanceRequest,
  triageMaintenanceRequest,
  convertMaintenanceRequestToWorkOrder
};
