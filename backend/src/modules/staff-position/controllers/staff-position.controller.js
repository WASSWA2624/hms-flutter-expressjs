/**
 * Staff position controller
 */

const staffPositionService = require('@services/staff-position/staff-position.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listStaffPositions = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    department_id,
    name,
    is_active,
    search,
    include_deleted,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    department_id,
    name,
    is_active,
    search,
    include_deleted
  };

  const result = await staffPositionService.listStaffPositions(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  sendPaginated(
    res,
    'messages.staff_position.list.success',
    result.staffPositions,
    result.pagination
  );
});

const getStaffPositionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const staffPosition = await staffPositionService.getStaffPositionById(id);
  sendSuccess(res, 200, 'messages.staff_position.get.success', staffPosition);
});

const createStaffPosition = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const staffPosition = await staffPositionService.createStaffPosition(
    req.body,
    userId,
    ipAddress
  );
  sendSuccess(res, 201, 'messages.staff_position.create.success', staffPosition);
});

const updateStaffPosition = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const staffPosition = await staffPositionService.updateStaffPosition(
    id,
    req.body,
    userId,
    ipAddress
  );
  sendSuccess(res, 200, 'messages.staff_position.update.success', staffPosition);
});

const deleteStaffPosition = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;
  await staffPositionService.deleteStaffPosition(id, userId, ipAddress);
  sendNoContent(res);
});

const restoreStaffPosition = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const staffPosition = await staffPositionService.restoreStaffPosition(
    id,
    userId,
    ipAddress
  );
  sendSuccess(res, 200, 'messages.staff_position.restore.success', staffPosition);
});

const permanentDeleteStaffPosition = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;
  await staffPositionService.permanentDeleteStaffPosition(id, userId, ipAddress);
  sendNoContent(res);
});

module.exports = {
  listStaffPositions,
  getStaffPositionById,
  createStaffPosition,
  updateStaffPosition,
  deleteStaffPosition,
  restoreStaffPosition,
  permanentDeleteStaffPosition
};
