/**
 * Roster day off controller
 */
const rosterDayOffService = require('@services/roster-day-off/roster-day-off.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const list = asyncHandler(async (req, res) => {
  const { nurse_roster_id, staff_profile_id, off_date_from, off_date_to, page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'asc' } = req.query;
  const result = await rosterDayOffService.list(
    { nurse_roster_id, staff_profile_id, off_date_from, off_date_to },
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip
  );
  sendPaginated(res, 'messages.roster_day_off.list.success', result.items, result.pagination);
});

const getById = asyncHandler(async (req, res) => {
  const item = await rosterDayOffService.getById(req.params.id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.roster_day_off.get.success', item);
});

const create = asyncHandler(async (req, res) => {
  const item = await rosterDayOffService.create(req.body, req.user?.id, req.ip);
  sendSuccess(res, 201, 'messages.roster_day_off.create.success', item);
});

const update = asyncHandler(async (req, res) => {
  const item = await rosterDayOffService.update(req.params.id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.roster_day_off.update.success', item);
});

const remove = asyncHandler(async (req, res) => {
  await rosterDayOffService.remove(req.params.id, req.user?.id, req.ip);
  sendNoContent(res);
});

module.exports = { list, getById, create, update, remove };
