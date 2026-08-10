/**
 * Roster controller
 *
 * @module modules/roster/controllers
 * @description Request handlers for roster endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const rosterService = require('@services/roster/roster.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listRosters = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    department_id,
    status,
    period_start_from,
    period_start_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    department_id,
    status,
    period_start_from,
    period_start_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await rosterService.listRosters(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.roster.list.success', result.rosters, result.pagination);
});

const getRosterById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const includeDeleted =
    String(req.query?.include_deleted || '').toLowerCase() === 'true' ||
    String(req.query?.include_deleted || '') === '1';

  const roster = await rosterService.getRosterById(id, { includeDeleted });

  sendSuccess(res, 200, 'messages.roster.get.success', roster);
});

const createRoster = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.createRoster(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.roster.create.success', roster);
});

const updateRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.updateRoster(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.roster.update.success', roster);
});

const deleteRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await rosterService.deleteRoster(id, userId, ipAddress);

  sendNoContent(res);
});

const restoreRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.restoreRoster(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.roster.restore.success', roster);
});

const permanentDeleteRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await rosterService.permanentDeleteRoster(id, userId, ipAddress);

  sendNoContent(res);
});

const publishRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { notify_staff = true } = req.body;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.publishRoster(id, notify_staff, userId, ipAddress);

  sendSuccess(res, 200, 'messages.roster.publish.success', roster);
});

const generateRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.generateRoster(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.roster.generate.success', roster);
});

const attachRosterStaff = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.attachRosterStaff(
    id,
    req.body.staff_profile_id,
    userId,
    ipAddress,
    { staff_category: req.body.staff_category }
  );

  sendSuccess(res, 200, 'messages.roster.attach_staff.success', roster);
});

const detachRosterStaff = asyncHandler(async (req, res) => {
  const { id, staffProfileId } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await rosterService.detachRosterStaff(
    id,
    staffProfileId,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.roster.detach_staff.success', roster);
});

module.exports = {
  listRosters,
  getRosterById,
  createRoster,
  updateRoster,
  deleteRoster,
  restoreRoster,
  permanentDeleteRoster,
  publishRoster,
  generateRoster,
  attachRosterStaff,
  detachRosterStaff,
};
