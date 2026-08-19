/**
 * Departments & Cost Centres controller
 *
 * @module modules/accounts-workspace/controllers
 * @description Request/response layer for Departments & Cost Centres. Business
 * rules, scope, and audit live in the service.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const departmentService = require('@services/accounts-workspace/department-cost-centre.service');

const listDepartments = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by: sortBy,
    order,
    ...filters
  } = req.query;

  const result = await departmentService.listDepartments(
    filters,
    Number(page),
    Number(limit),
    req.user,
    sortBy,
    order
  );

  return sendPaginated(
    res,
    'messages.accounts.department.list.success',
    result.items,
    result.pagination
  );
});

const getDepartment = asyncHandler(async (req, res) => {
  const data = await departmentService.getDepartment(
    req.params.departmentIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(res, 200, 'messages.accounts.department.get.success', data);
});

const createDepartment = asyncHandler(async (req, res) => {
  const data = await departmentService.createDepartment(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    201,
    'messages.accounts.department.create.success',
    data
  );
});

const updateDepartment = asyncHandler(async (req, res) => {
  const data = await departmentService.updateDepartment(
    req.params.departmentIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.department.update.success',
    data
  );
});

const applyDepartmentAction = asyncHandler(async (req, res) => {
  const data = await departmentService.applyDepartmentAction(
    req.params.departmentIdentifier,
    req.params.action,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.department.action.success',
    data
  );
});

module.exports = {
  listDepartments,
  getDepartment,
  createDepartment,
  updateDepartment,
  applyDepartmentAction,
};
