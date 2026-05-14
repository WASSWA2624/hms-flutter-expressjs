/**
 * Department controller
 *
 * @module modules/department/controllers
 * @description Handles HTTP requests for department endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const departmentService = require('@services/department/department.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List departments with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listDepartments = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, branch_id, department_type, is_active, search } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (branch_id) filters.branch_id = branch_id;
  if (department_type) filters.department_type = department_type;
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;

  const result = await departmentService.listDepartments(
    filters,
    page,
    limit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.department.list.success',
    result.departments,
    result.pagination
  );
});

/**
 * Get department by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getDepartmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const department = await departmentService.getDepartmentById(id);

  return sendSuccess(res, 200, 'messages.department.get.success', department);
});

/**
 * Create department
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createDepartment = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const department = await departmentService.createDepartment(data, context);

  return sendSuccess(res, 201, 'messages.department.create.success', department);
});

/**
 * Update department
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateDepartment = asyncHandler(async (req, res) => {
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

  const department = await departmentService.updateDepartment(id, data, context);

  return sendSuccess(res, 200, 'messages.department.update.success', department);
});

/**
 * Delete department
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteDepartment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await departmentService.deleteDepartment(id, context);

  return sendNoContent(res);
});

/**
 * Get department units (nested resource)
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getDepartmentUnits = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { page, limit } = req.query;

  const result = await departmentService.getDepartmentUnits(id, page, limit);

  return sendPaginated(
    res,
    'messages.department.units.list.success',
    result.units,
    result.pagination
  );
});

module.exports = {
  listDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  deleteDepartment,
  getDepartmentUnits
};
