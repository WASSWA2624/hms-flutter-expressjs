/**
 * Ambulance controller
 *
 * @module modules/ambulance/controllers
 * @description Handles HTTP requests for ambulance endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const ambulanceService = require('@services/ambulance/ambulance.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List ambulances with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listAmbulances = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, status, search } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (status) filters.status = status;
  if (search) filters.search = search;

  const result = await ambulanceService.listAmbulances(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.ambulance.list.success',
    result.ambulances,
    result.pagination
  );
});

/**
 * Get ambulance by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getAmbulanceById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const ambulance = await ambulanceService.getAmbulanceById(id);

  return sendSuccess(res, 200, 'messages.ambulance.get.success', ambulance);
});

/**
 * Create ambulance
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createAmbulance = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const ambulance = await ambulanceService.createAmbulance(data, context);

  return sendSuccess(res, 201, 'messages.ambulance.create.success', ambulance);
});

/**
 * Update ambulance
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateAmbulance = asyncHandler(async (req, res) => {
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

  const ambulance = await ambulanceService.updateAmbulance(id, data, context);

  return sendSuccess(res, 200, 'messages.ambulance.update.success', ambulance);
});

/**
 * Delete ambulance
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteAmbulance = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await ambulanceService.deleteAmbulance(id, context);

  return sendNoContent(res);
});

module.exports = {
  listAmbulances,
  getAmbulanceById,
  createAmbulance,
  updateAmbulance,
  deleteAmbulance
};
