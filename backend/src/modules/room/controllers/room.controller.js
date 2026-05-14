/**
 * Room controller
 *
 * @module modules/room/controllers
 * @description Handles HTTP requests for room endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const roomService = require('@services/room/room.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List rooms with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listRooms = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, ward_id, search } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (ward_id) filters.ward_id = ward_id;
  if (search) filters.search = search;

  const result = await roomService.listRooms(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.room.list.success',
    result.rooms,
    result.pagination
  );
});

/**
 * Get room by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getRoomById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const room = await roomService.getRoomById(id);

  return sendSuccess(res, 200, 'messages.room.get.success', room);
});

/**
 * Create room
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createRoom = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const room = await roomService.createRoom(data, context);

  return sendSuccess(res, 201, 'messages.room.create.success', room);
});

/**
 * Update room
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateRoom = asyncHandler(async (req, res) => {
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

  const room = await roomService.updateRoom(id, data, context);

  return sendSuccess(res, 200, 'messages.room.update.success', room);
});

/**
 * Delete room
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteRoom = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await roomService.deleteRoom(id, context);

  return sendNoContent(res);
});

module.exports = {
  listRooms,
  getRoomById,
  createRoom,
  updateRoom,
  deleteRoom
};
