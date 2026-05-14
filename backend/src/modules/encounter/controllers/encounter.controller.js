/**
 * Encounter controller
 *
 * @module modules/encounter/controllers
 * @description Request handlers for encounter endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const encounterService = require('@services/encounter/encounter.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List encounters with pagination
 * GET /api/v1/encounters
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listEncounters = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    provider_user_id,
    encounter_type,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    provider_user_id,
    encounter_type,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await encounterService.listEncounters(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.encounter.list.success', result.encounters, result.pagination);
});

/**
 * Get encounter by ID
 * GET /api/v1/encounters/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getEncounterById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const encounter = await encounterService.getEncounterById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.encounter.get.success', encounter);
});

/**
 * Create new encounter
 * POST /api/v1/encounters
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createEncounter = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const encounter = await encounterService.createEncounter(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.encounter.create.success', encounter);
});

/**
 * Update encounter
 * PUT /api/v1/encounters/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateEncounter = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const encounter = await encounterService.updateEncounter(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.encounter.update.success', encounter);
});

/**
 * Delete encounter (soft delete)
 * DELETE /api/v1/encounters/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteEncounter = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await encounterService.deleteEncounter(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listEncounters,
  getEncounterById,
  createEncounter,
  updateEncounter,
  deleteEncounter
};
