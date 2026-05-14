/**
 * Availability slot controller
 *
 * @module modules/availability-slot/controllers
 * @description Request handlers for availability slot endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const availabilitySlotService = require('@services/availability-slot/availability-slot.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List availability slots with pagination
 * GET /api/v1/availability-slots
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAvailabilitySlots = asyncHandler(async (req, res) => {
  const {
    schedule_id,
    override_date,
    is_available,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    schedule_id,
    override_date,
    is_available
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await availabilitySlotService.listAvailabilitySlots(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.availability_slot.list.success', result.slots, result.pagination);
});

/**
 * Get availability slot by ID
 * GET /api/v1/availability-slots/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAvailabilitySlotById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const slot = await availabilitySlotService.getAvailabilitySlotById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.availability_slot.get.success', slot);
});

/**
 * Create new availability slot
 * POST /api/v1/availability-slots
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAvailabilitySlot = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const slot = await availabilitySlotService.createAvailabilitySlot(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.availability_slot.create.success', slot);
});

/**
 * Update availability slot
 * PUT /api/v1/availability-slots/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAvailabilitySlot = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const slot = await availabilitySlotService.updateAvailabilitySlot(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.availability_slot.update.success', slot);
});

/**
 * Delete availability slot (soft delete)
 * DELETE /api/v1/availability-slots/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAvailabilitySlot = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await availabilitySlotService.deleteAvailabilitySlot(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listAvailabilitySlots,
  getAvailabilitySlotById,
  createAvailabilitySlot,
  updateAvailabilitySlot,
  deleteAvailabilitySlot
};
