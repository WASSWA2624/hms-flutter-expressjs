/**
 * Nurse roster controller
 *
 * @module modules/nurse-roster/controllers
 * @description Request handlers for nurse roster endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const nurseRosterService = require('@services/nurse-roster/nurse-roster.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listNurseRosters = asyncHandler(async (req, res) => {
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

  const result = await nurseRosterService.listNurseRosters(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.nurse_roster.list.success', result.rosters, result.pagination);
});

const getNurseRosterById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await nurseRosterService.getNurseRosterById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.nurse_roster.get.success', roster);
});

const createNurseRoster = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await nurseRosterService.createNurseRoster(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.nurse_roster.create.success', roster);
});

const updateNurseRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await nurseRosterService.updateNurseRoster(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.nurse_roster.update.success', roster);
});

const deleteNurseRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await nurseRosterService.deleteNurseRoster(id, userId, ipAddress);

  sendNoContent(res);
});

const publishNurseRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { notify_staff = true } = req.body;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await nurseRosterService.publishNurseRoster(id, notify_staff, userId, ipAddress);

  sendSuccess(res, 200, 'messages.nurse_roster.publish.success', roster);
});

const generateNurseRoster = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const roster = await nurseRosterService.generateNurseRoster(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.nurse_roster.generate.success', roster);
});

module.exports = {
  listNurseRosters,
  getNurseRosterById,
  createNurseRoster,
  updateNurseRoster,
  deleteNurseRoster,
  publishNurseRoster,
  generateNurseRoster
};
