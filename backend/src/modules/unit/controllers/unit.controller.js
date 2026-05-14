/**
 * Unit controller
 *
 * @module modules/unit/controllers
 * @description Handles HTTP requests for unit endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const unitService = require('@services/unit/unit.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List units with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listUnits = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, department_id, is_active, search } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (department_id) filters.department_id = department_id;
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;

  const result = await unitService.listUnits(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.unit.list.success',
    result.units,
    result.pagination
  );
});

/**
 * Get unit by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getUnitById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const unit = await unitService.getUnitById(id);

  return sendSuccess(res, 200, 'messages.unit.get.success', unit);
});

/**
 * Create unit
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createUnit = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const unit = await unitService.createUnit(data, context);

  return sendSuccess(res, 201, 'messages.unit.create.success', unit);
});

/**
 * Update unit
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateUnit = asyncHandler(async (req, res) => {
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

  const unit = await unitService.updateUnit(id, data, context);

  return sendSuccess(res, 200, 'messages.unit.update.success', unit);
});

/**
 * Delete unit
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteUnit = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await unitService.deleteUnit(id, context);

  return sendNoContent(res);
});

module.exports = {
  listUnits,
  getUnitById,
  createUnit,
  updateUnit,
  deleteUnit
};
