/**
 * Bed controller
 *
 * @module modules/bed/controllers
 * @description Handles HTTP requests for bed endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const bedService = require('@services/bed/bed.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List beds with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listBeds = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, ward_id, room_id, status, search } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (ward_id) filters.ward_id = ward_id;
  if (room_id) filters.room_id = room_id;
  if (status) filters.status = status;
  if (search) filters.search = search;

  const result = await bedService.listBeds(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.bed.list.success',
    result.beds,
    result.pagination
  );
});

/**
 * Get bed by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getBedById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const bed = await bedService.getBedById(id);

  return sendSuccess(res, 200, 'messages.bed.get.success', bed);
});

/**
 * Create bed
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createBed = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const bed = await bedService.createBed(data, context);

  return sendSuccess(res, 201, 'messages.bed.create.success', bed);
});

/**
 * Update bed
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateBed = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const bed = await bedService.updateBed(id, data, context);

  return sendSuccess(res, 200, 'messages.bed.update.success', bed);
});

/**
 * Delete bed
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteBed = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await bedService.deleteBed(id, context);

  return sendNoContent(res);
});

module.exports = {
  listBeds,
  getBedById,
  createBed,
  updateBed,
  deleteBed
};
