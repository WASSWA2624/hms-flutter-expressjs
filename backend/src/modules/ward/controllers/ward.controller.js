/**
 * Ward controller
 *
 * @module modules/ward/controllers
 * @description Handles HTTP requests for ward endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const wardService = require('@services/ward/ward.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List wards with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listWards = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, department_id, ward_type, is_active, search } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (department_id) filters.department_id = department_id;
  if (ward_type) filters.ward_type = ward_type;
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;

  const result = await wardService.listWards(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.ward.list.success',
    result.wards,
    result.pagination
  );
});

/**
 * Get ward by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getWardById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const ward = await wardService.getWardById(id);

  return sendSuccess(res, 200, 'messages.ward.get.success', ward);
});

/**
 * Create ward
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createWard = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const ward = await wardService.createWard(data, context);

  return sendSuccess(res, 201, 'messages.ward.create.success', ward);
});

/**
 * Update ward
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateWard = asyncHandler(async (req, res) => {
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

  const ward = await wardService.updateWard(id, data, context);

  return sendSuccess(res, 200, 'messages.ward.update.success', ward);
});

/**
 * Delete ward
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteWard = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await wardService.deleteWard(id, context);

  return sendNoContent(res);
});

/**
 * Get ward beds (nested resource)
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getWardBeds = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const ward = await wardService.getWardBeds(id);

  return sendSuccess(res, 200, 'messages.ward.beds.list.success', ward);
});

module.exports = {
  listWards,
  getWardById,
  createWard,
  updateWard,
  deleteWard,
  getWardBeds
};
