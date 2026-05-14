/**
 * Staff availability controller
 */
const staffAvailabilityService = require('@services/staff-availability/staff-availability.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const list = asyncHandler(async (req, res) => {
  const { staff_profile_id, day_of_week, preference, page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc' } = req.query;
  const result = await staffAvailabilityService.list(
    { staff_profile_id, day_of_week, preference },
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip
  );
  sendPaginated(res, 'messages.staff_availability.list.success', result.items, result.pagination);
});

const getById = asyncHandler(async (req, res) => {
  const item = await staffAvailabilityService.getById(req.params.id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.staff_availability.get.success', item);
});

const create = asyncHandler(async (req, res) => {
  const item = await staffAvailabilityService.create(req.body, req.user?.id, req.ip);
  sendSuccess(res, 201, 'messages.staff_availability.create.success', item);
});

const update = asyncHandler(async (req, res) => {
  const item = await staffAvailabilityService.update(req.params.id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.staff_availability.update.success', item);
});

const remove = asyncHandler(async (req, res) => {
  await staffAvailabilityService.remove(req.params.id, req.user?.id, req.ip);
  sendNoContent(res);
});

module.exports = { list, getById, create, update, remove };
