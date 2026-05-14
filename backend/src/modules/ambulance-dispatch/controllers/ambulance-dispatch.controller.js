/**
 * Ambulance Dispatch controller
 *
 * @module modules/ambulance-dispatch/controllers
 * @description Handles HTTP requests for ambulance dispatch endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const ambulanceDispatchService = require('@services/ambulance-dispatch/ambulance-dispatch.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List ambulance dispatches with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listAmbulanceDispatches = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ambulance_id, emergency_case_id, status, search } = req.query;

  const filters = {};
  if (ambulance_id) filters.ambulance_id = ambulance_id;
  if (emergency_case_id) filters.emergency_case_id = emergency_case_id;
  if (status) filters.status = status;
  if (search) filters.search = search;

  const result = await ambulanceDispatchService.listAmbulanceDispatches(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.ambulance_dispatch.list.success',
    result.dispatches,
    result.pagination
  );
});

/**
 * Get ambulance dispatch by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getAmbulanceDispatchById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const dispatch = await ambulanceDispatchService.getAmbulanceDispatchById(id);

  return sendSuccess(res, 200, 'messages.ambulance_dispatch.get.success', dispatch);
});

/**
 * Create ambulance dispatch
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createAmbulanceDispatch = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const dispatch = await ambulanceDispatchService.createAmbulanceDispatch(data, context);

  return sendSuccess(res, 201, 'messages.ambulance_dispatch.create.success', dispatch);
});

/**
 * Update ambulance dispatch
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateAmbulanceDispatch = asyncHandler(async (req, res) => {
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

  const dispatch = await ambulanceDispatchService.updateAmbulanceDispatch(id, data, context);

  return sendSuccess(res, 200, 'messages.ambulance_dispatch.update.success', dispatch);
});

/**
 * Delete ambulance dispatch
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteAmbulanceDispatch = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await ambulanceDispatchService.deleteAmbulanceDispatch(id, context);

  return sendNoContent(res);
});

module.exports = {
  listAmbulanceDispatches,
  getAmbulanceDispatchById,
  createAmbulanceDispatch,
  updateAmbulanceDispatch,
  deleteAmbulanceDispatch
};
