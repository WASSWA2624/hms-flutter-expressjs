/**
 * Ambulance Trip controller
 *
 * @module modules/ambulance-trip/controllers
 * @description Handles HTTP requests for ambulance trip endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const ambulanceTripService = require('@services/ambulance-trip/ambulance-trip.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List ambulance trips with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listAmbulanceTrips = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ambulance_id, emergency_case_id, search } = req.query;

  const filters = {};
  if (ambulance_id) filters.ambulance_id = ambulance_id;
  if (emergency_case_id) filters.emergency_case_id = emergency_case_id;
  if (search) filters.search = search;

  const result = await ambulanceTripService.listAmbulanceTrips(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.ambulance_trip.list.success',
    result.trips,
    result.pagination
  );
});

/**
 * Get ambulance trip by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getAmbulanceTripById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const trip = await ambulanceTripService.getAmbulanceTripById(id);

  return sendSuccess(res, 200, 'messages.ambulance_trip.get.success', trip);
});

/**
 * Create ambulance trip
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createAmbulanceTrip = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const trip = await ambulanceTripService.createAmbulanceTrip(data, context);

  return sendSuccess(res, 201, 'messages.ambulance_trip.create.success', trip);
});

/**
 * Update ambulance trip
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateAmbulanceTrip = asyncHandler(async (req, res) => {
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

  const trip = await ambulanceTripService.updateAmbulanceTrip(id, data, context);

  return sendSuccess(res, 200, 'messages.ambulance_trip.update.success', trip);
});

/**
 * Delete ambulance trip
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteAmbulanceTrip = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await ambulanceTripService.deleteAmbulanceTrip(id, context);

  return sendNoContent(res);
});

module.exports = {
  listAmbulanceTrips,
  getAmbulanceTripById,
  createAmbulanceTrip,
  updateAmbulanceTrip,
  deleteAmbulanceTrip
};
